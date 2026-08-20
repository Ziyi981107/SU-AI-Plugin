# Next-Stage Options for Owner (2026-08-19)

From: Coding Agent (Mavis), continuing the work of Coding Agent (Pi)

## Where the project stands right now

V1.0 / TASK 001 is **functionally complete on the verified host**
(SketchUp 2020). The stable baseline is locked at commit
`56ea611` (the head after this session's three cleanup commits):

| Item                                | Status      | Evidence                                       |
|-------------------------------------|-------------|------------------------------------------------|
| Stage 6 Owner verification (K..N)   | PASS        | `Review/OWNER_VERIFICATION_STAGE_6.txt`        |
| Gate 2 install on real SU2020       | PASS        | `Review/OWNER_VERIFICATION_RBZ_INSTALL_2026-08-19.txt` |
| RBZ package + root loader structure | PASS        | CodeX Review 024 (BLOCK-022/023 closed)        |
| Package-structure migration tail    | DONE        | commits `8814455`, `b0c16c8`                   |
| Full test suite                     | 286/286 PASS | `tests/run_all.rb` (run `2026-08-19`)          |
| Gate 1 (real SU2017)                | **PENDING** | R004 posture B; Owner host not available       |

The `dist/SU-AI-Plugin.rbz` currently checked in is the V1.0
candidate (178,108 bytes, built 2026-08-19 15:55:22).

**Nothing in this baseline is "half-done".** The migration tail that
was on disk when I picked up the project has been committed; the
`scripts/stop_monitor.ps1` workflow helper has been added; the
`CURRENT_STATE.md` handoff block is updated. If you want me to STOP
here, the V1.0 candidate is ready for you to keep on the shelf
until SU2017 is available.

## What I have NOT done, and why

Per the Pi handoff (`Prompt/PI_NEXT_STAGE_HANDOFF_2026-08-19.txt`)
and the project rules (`AGENT.md` §2, §3), I am explicitly NOT going
to:

- Start a new product feature without your direction.
- Submit tiny edit packets to CodeX for review.
- Reopen any Stage 6 / Gate 2 / RBZ scope that has already passed.
- Treat Gate 2 SU2020 evidence as Gate 1 SU2017 evidence.

The handoff was very specific: **"If the next feature scope is not
actually defined in project materials, do not fabricate it."** I have
no project materials that define a V1.1 feature beyond the
"deferred / out-of-scope" list in the original `PI_TASK_001 §17`
block. That list is a list of things explicitly NOT in V1.0 scope,
not a list of things promised for V1.1.

## Options for the next stage

Pick one, or describe something different. I will not act until
you do.

**Reviewer routing per option** (per the Pi handoff, §"Use the
least expensive appropriate reviewer"):

- **Agent self** — routine coding, ordinary refactor, test fix,
  anything that does NOT need an external reviewer.
- **ChatGPT** — product / priority / UX / wording / scope
  questions, routine tradeoffs, planning discussion that does NOT
  need source / Git / diff inspection.
- **CodeX** — source / Git / diff review, architecture / data /
  state / persistence / security issues, real-host or RBZ
  failure, final release review, BLOCK recheck. Triggered only
  on a complete coherent stage or a recheck packet, never on
  per-edit progress pings.

### Option A — STOP and wait for SU2017 (no code work)

**Reviewer for the wait decision: ChatGPT** (pure scope / priority
question; no source or diff needed). **Reviewer for the SU2017
re-verify, when it happens: CodeX** (real-host release gate
evidence; if Gate 1 BLOCKs, the BLOCK recheck is also CodeX).

Use the time to wait for SU2017 availability. When it shows up,
I will:
1. Re-verify the existing V1.0 RBZ on SU2017 (no code change).
2. Report Gate 1 PASS or BLOCK.
3. Decide together whether the existing V1.0 candidate is the
   release artifact, or whether Gate 1 forces a fix release.

This is the lowest-risk path. It does NOT advance the product; it
just protects the V1.0 candidate.

### Option B — A small hardening pass on the V1.0 candidate

**Reviewer for picking which hardening item: ChatGPT** (UX /
priority question; no source or diff needed).
**Reviewer for the implementation: Agent self** (ordinary
implementation; no CodeX review per the handoff cadence —
hardening NITs are explicitly NOT a CodeX trigger).
**Reviewer for the final re-Gate-2 run: Agent self** (target
host is the same SU2020 you already verified, no new evidence
type).

If you have spare time and want to invest in stability without
expanding scope, candidate hardening items (all are pure quality,
no new product behavior):
- Add a "skipped entities" counter to the analysis summary so
  it is visible when traversal skips an entity (e.g. a malformed
  Edge). Right now they only show up as `warnings` if the warning
  bucket catches them.
- Add a real-host self-test stub inside the entrypoint so a
  fresh install on a real host prints a one-line "plugin loaded
  successfully" message to the Ruby Console for the first 30s.
  This makes "did it actually load" trivial to answer without
  having to click the menu.
- Convert the "no Ruby 2.2.4 binary in the dev env" caveat in
  `CURRENT_STATE.md` from a manual checklist item into an
  automated syntax check (e.g. a Ruby 2.2-compatible parser
  lint in CI when we have CI). Low priority; only useful if you
  anticipate a real release with a long tail of older hosts.
- Write a `README.md` user guide section explaining the dialog
  results page and the "non-locatable" / "no-action" rule
  (`L3` lesson). Currently the rule is documented in test files
  and CURRENT_STATE, not in the user-facing surface.

None of these expand the product contract. None of them change
what the user sees. All of them can be added and re-Gate-2'd
on the same SU2020 host, with no Gate 1 dependency.

### Option C — A real V1.1 feature, from the deferred list

**Reviewer for picking the V1.1 candidate: ChatGPT** (scope /
priority / UX question; this is exactly the "do NOT require
direct code inspection" lane).
**Reviewer for the plan before implementation: CodeX** (the
handoff is explicit: "Codex is the default technical reviewer
when direct source/Git/diff review is genuinely needed,
especially for a meaningful coherent stage, high-risk
architecture / data / state / persistence / security issue ...
or final release review"). A V1.1 plan is a meaningful coherent
stage.
**Reviewer for the implementation itself: Agent self**, with
CodeX invoked only at the end-of-stage boundary (per the
handoff "do NOT submit tiny edit packets" rule).

The original `PI_TASK_001 §17` "out of scope" list enumerates the
plausible V1.1 candidates. If you want to start V1.1, the most
natural first item is one of:

- **Layer semantic mapping** (e.g. "label layers with rough
  function: dimensions / construction / annotation"). Pure
  read-only analysis, fits the existing "do not modify the
  model" contract, extends the existing per-issue grouping.
- **Face / polygon extraction** (extend the per-edge analysis
  with the face each edge bounds, when computable from the
  current selection). Still read-only; useful for downstream
  users.
- **Settings UI (minimal)** (persisted tolerance, large-coord
  threshold, render units — currently all hardcoded in
  `Tolerance`). The smallest user-visible V1.1 change.

Anything from this list needs a fresh scope doc + a CodeX
review of the plan, per the handoff cadence. I will not start
without an explicit direction.

### Option D — Re-open / re-verify something already passed

**Reviewer for the regression triage: Agent self** (investigate
the specific scenario; do NOT sweep).
**Reviewer for any resulting fix: depends on what comes out**.
  * Pure test fix / NIT → Agent self.
  * Real-host or RBZ issue → CodeX BLOCK recheck packet.
  * Scope change to handle the regression → ChatGPT for the
    scope call, then CodeX for the plan.

If you have evidence that a previously-PASSed scope has actually
regressed (e.g. you ran the RBZ on a different model and got a
wrong result), tell me which scenario and I will re-test. I will
NOT re-test on speculation; that is what "do not reopen
previously passed scope" means in the handoff.

## What I will do once you pick

- A → wait, do nothing, only re-engage on SU2017 arrival.
- B → implement in this session, self-test, commit, re-run the
  full suite, write a `Review/HARDENING_<date>.md` report.
  CodeX review is NOT required for hardening NITs.
- C → write a short scope doc first, then submit ONE CodeX
  review packet for the plan. Implementation starts only after
  CodeX verdict on the plan.
- D → investigate the specific scenario you describe, do not
  start with a "let me re-run everything" sweep.

## What stays open regardless of choice

Gate 1 (SU2017 real-host verification) remains the final
release-gate item per R004 posture B. Until you have a SU2017
host, it stays PENDING. No option above closes it.

## Things you can ignore

- The 23 untracked files in `Prompt/` and `Review/` are Codex
  / Owner input and historical review packets. They are
  intentionally not committed. The `.gitignore` already
  excludes `data/_check_tmp/`, `.vendor/`, and all build
  outputs. The empty `extension/.staging/` directory is a
  build-script leftover; it is not tracked and is harmless.
- The git author on the three new commits is "Coding Agent
  (Mavis)". This is a deliberate author change from the
  previous "Coding Agent (Pi)" to make the agent-handoff
  boundary visible in the log. Email is unchanged
  (`agent@su-ai-plugin.local`).

END
