# V1.5 Stage Block Recheck — Round 2 Evidence Re-confirm + Environment Recovery
**Date:** 2026-08-26
**Owner:** Pi
**Status:** Evidence re-confirm (no source-code change in this session)
**Related verdict:** `Prompt/CODEX_REVIEW_033_V1_5_DERIVED_EDGE_BLOCK_RECHECK_2026-08-25.txt`
   (STATUS: COMPLETE / VERDICT: BLOCKED, 5 new V15-STAGE-BLOCK-001..005)

----------------------------------------------------------------------
0. Purpose of this artifact
----------------------------------------------------------------------

This file records:

1. The targeted Ruby environment recovery performed after the previous
   shell was forcibly closed mid-test.
2. The independent re-run of the V1.5 round-2 test evidence at
   `7283a83` (the round-2 fix packet).
3. The current active V1.5 task state now that Review 033 has arrived.
4. Pi's hard compliance with the no-source-change rule during this
   environment investigation.

No production code, test code, RBZ, or governance file is changed by
this artifact.

----------------------------------------------------------------------
1. Environment recovery (Ruby)
----------------------------------------------------------------------

Symptom (interrupted previous session):

  - `ruby tests/run_all.rb` -> `/c/Ruby27-x64/bin/ruby: Permission denied`
  - `which ruby`             -> `/c/Ruby27-x64/bin/ruby`
  - `where.exe ruby`         -> `C:\Ruby27-x64\bin\ruby.exe`
  - `ruby --version`         -> same Permission denied
  - A subsequent `find / -name 'ruby.exe'` got stuck scanning the
    whole filesystem; the shell was forcibly closed.

Diagnosis (targeted, no full-filesystem scan):

  - Shell              : Git Bash (MSYS2 / MINGW64_NT-10.0-19045)
  - which/where        : both resolve to `C:\Ruby27-x64\bin\ruby.exe`
  - File ACL           : fine (Administrators: F, Users: RX via `icacls`)
  - File format        : PE32+ Windows console, identical 34304-byte
                         image as the bundled Ruby 2.7.8 below
  - Launch attempt     : fails identically under `cmd.exe` AND
                         `powershell.exe` with Windows SxS error:
                           应用程序无法启动，因为应用程序的并行配置不正确
                           (ERROR_SXS_INVALID_DEACTIVATION)
  - Root cause         : the externally-installed `C:\Ruby27-x64`
                         Ruby 2.7 has a broken VC++ runtime / SxS
                         configuration on this host. The host itself
                         refuses to launch the .exe. This is not an
                         ACL problem and not a Git-Bash problem.

Valid executable already shipped inside the project:

  Path   : `D:/Projects/SU-AI-Plugin/.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`
  Version: `ruby 2.7.8p225 (2023-03-30 revision 1f4d455848) [x64-mingw32]`
  This is exactly the bundled toolchain named in
  `PROJECT_HANDOFF.txt` §5 ("./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe").

Recovery action (session-level, no system-wide change):

  All Ruby invocations in this session use the bundled executable
  explicitly by full path. No PATH rewrite, no reinstall, no ACL
  change, no registry change, no environment-variable mutation.

  Sanity check command:

      ./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe --version
      -> ruby 2.7.8p225 (2023-03-30 revision 1f4d455848) [x64-mingw32]

----------------------------------------------------------------------
2. Targeted V1.5 tests (re-run after environment recovery)
----------------------------------------------------------------------

Filter used: substring `V15` against `tests/run_all.rb`.

Command:

  ./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb V15

Result:

  65 tests: 65 pass, 0 fail, 0 error

The 65 tests cover the full V1.5 surface used by round-2 evidence:

  - V15-1 .. V15-14 (core duplicate-repair matrices)
  - V15-DET-1..2, V15-WMR-1..2, V15-RA-1..2, V15-SANITY
  - V15-F, V15-L, V15-M, V15-P, V15-O, V15-Q, V15-Q-UI
  - V15-E, V15-I (Owner-draft edge cases)
  - V15-B001-1..5  (BLOCK-001 narrow-scope fix tests, round 2)
  - V15-B002-1..5  (BLOCK-002 narrow-scope fix tests, round 2)
  - V15-B003-1..5  (BLOCK-003 narrow-scope fix tests, round 2)
  - V15-B004-1..5  (BLOCK-004 narrow-scope fix tests, round 2)
  - V15PC-001..010 (production call-chain tests, round 2)
  - V15RP-001..005 (real PreflightRunner path tests, round 2)

----------------------------------------------------------------------
3. Full Ruby suite (re-run after environment recovery)
----------------------------------------------------------------------

Command:

  ./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe tests/run_all.rb

Result:

  729 tests: 729 pass, 0 fail, 0 error

Comparison to previously-recorded evidence:

  - Round-2 evidence recorded in
    `Review/V15_DERIVED_EDGE_CANONICALIZATION_BLOCK_RECHECK_2026-08-25.md`
    section 2 also stated 729/729. The number is identical because
    this is the same committed state (HEAD `7283a83`).
  - This re-run is independent: performed from a fresh shell invocation
    against the committed tree at `7283a83`, using the bundled Ruby.
    No result was copied; no PASS line is fabricated.

----------------------------------------------------------------------
4. Git state at the time of this artifact
----------------------------------------------------------------------

  HEAD:               7283a830c0eb8979ad5c78ced30d8cffc790bc75
                      fix(v1.5-stage4-block-recheck): CodeX BLOCK-001..005
                      narrow-scope fixes (round 2)
  Branch:             v1.5-high-confidence-auto-repair
  git diff --check:   clean (exit 0)
  git diff --check 720e7c0..HEAD:
                      clean (exit 0)
  working tree:
                      ?? Prompt/CODEX_REVIEWER_CONTRACT_V3_2026-08-25.txt
                      ?? Prompt/CODEX_REVIEW_033_V1_5_DERIVED_EDGE_BLOCK_RECHECK_2026-08-25.txt
                      ?? Prompt_Stage.txt
                      These three untracked files match the state
                      Review 033 itself recorded when it was created.
                      No tracked file is dirty.

----------------------------------------------------------------------
5. New active verdict (just arrived)
----------------------------------------------------------------------

`Prompt/CODEX_REVIEW_033_V1_5_DERIVED_EDGE_BLOCK_RECHECK_2026-08-25.txt`

  STATUS          : COMPLETE
  VERDICT         : BLOCKED
  REASONING EFFORT: xHigh
  ACTIVE BLOCKS   : V15-STAGE-BLOCK-001..005 (round 3 set)

Summary of where round 2 still falls short per Review 033:

  BLOCK-001: final destructive classes bypass complete identity
             and live-handle uniqueness proof (proposer.rb lines
             552-691, 717-906, 913-1006).
  BLOCK-002: non-transitive classes and bucket-boundary candidates
             remain unsafe/incomplete (proposer + validator +
             duplicate_detector). V15-B002-5 not a genuine proof.
  BLOCK-003: complete post-state validation still occurs after
             host commit; pre-host check proves only surviving IDs
             (executor + working_mode_runner).
  BLOCK-004: production validation/audit data still false or
             incomplete. Captured tolerance not propagated;
             skipped rows erased; pair counts fabricated; failed
             invariant can leave state=ready.
  BLOCK-005: Owner verification draft and Pi packet not yet
             executable / truthful. Undo observation wrong; layer
             test does not create the claimed conflict; no
             observation path for issue_ids / summary JSON; old
             role labels; Pi packet placeholders for RBZ metadata.

Per Reviewer Contract V3 §18.7, the path is:

  "request one narrow recheck after one complete fix"

----------------------------------------------------------------------
6. What Pi has NOT done this session (hard rules honored)
----------------------------------------------------------------------

  - Did NOT use `find /` or any full-filesystem scan.
  - Did NOT modify any production source file.
  - Did NOT modify any test file.
  - Did NOT modify any RBZ.
  - Did NOT rewrite PROJECT_HANDOFF.txt.
  - Did NOT write anything under Prompt/.
  - Did NOT touch V1.0-V1.4 closed scope.
  - Did NOT touch V1.6.
  - Did NOT change Reviewer Contract V3 governance.
  - Did NOT change the role labels in any artifact.
  - Did NOT change RBZ smoke evidence or Node DOM evidence.
  - Did NOT change any prior claimed PASS line; the 729/729
    re-run in section 3 above is from a fresh shell invocation
    against the committed `7283a83` tree.

----------------------------------------------------------------------
7. What is ready for the next dispatch
----------------------------------------------------------------------

  - Bundled Ruby at
    `./.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`
    is healthy and reproducible for every subsequent test run.
  - Round-2 fix packet at `7283a83` is freshly re-confirmed
    (729/729) and is not regressed by any environmental issue.
  - The five new BLOCK-001..005 from Review 033 are catalogued
    with line numbers and root causes (see section 5 above and
    the verdict file itself for full text).
  - The auto-applied recheck contract is in place per V3 §18.7:
    one coherent round-3 fix packet followed by one narrow
    recheck. Pi is ready to begin the round-3 fix packet when
    dispatched.

----------------------------------------------------------------------
8. Pi STOP posture (no self-dispatch)
----------------------------------------------------------------------

Per V3 §18 / V3 §3 / PROJECT_HANDOFF §2, Pi does NOT auto-create a
new Codex guidance, does NOT dispatch itself the next round, and
does NOT enter V1.6. The next round-3 fix packet requires either:

  (a) a new `Prompt/CODEX_GUIDANCE_034_*.txt` from AIPM/Codex, or
  (b) an explicit Owner instruction to begin round 3 now.

Until then, this artifact is the durable record that:

  - the Ruby environment is healthy again (using the bundled Ruby),
  - round 2 evidence still stands (independently re-confirmed),
  - round 3 has not started, and
  - all hard rules have been honored in this session.

----------------------------------------------------------------------
END OF V1.5 ROUND-2 EVIDENCE RE-CONFIRM
----------------------------------------------------------------------
