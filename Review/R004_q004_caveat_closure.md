============================================================
R004 — Q004 CAVEAT CLOSURE CRITERIA
============================================================
Date:    2026-08-17
Status:  POSTURE NEEDED before claiming TASK 001 IMPLEMENTATION COMPLETE
Stage:   Gate (final)


RECAP
=====

Q004=A ("隔离运行时 + 真实跑 tests"). Per CODEX_GUIDANCE_003 §Q004:

  "应优先取得 Ruby 2.2.x 环境做最低基线验证;
   若当前只能取得更新的隔离 Ruby, 可先用它执行功能测试,
   但这不能单独证明 Ruby 2.2.4 兼容;
   在最终 Gate 前, 仍需补充 Ruby 2.2.4 / SU2017 的语法与目标环境证据."

Current state (commit 6eb33e8):
  - Functional tests run on isolated Ruby 2.7.8p225 → 33/33 PASS.
  - Static check: Stage 1 + Stage 2 code uses only Ruby 2.2.4-safe
    syntax (no pattern matching, no numbered params, no endless
    method, no kwargs sugar, no frozen_string_literal magic).

What is MISSING for the Q004 caveat:
  - No automated syntax-check pass against an actual Ruby 2.2.4
    interpreter (we only statically reasoned).
  - No Owner real-SU verification on SU2017 specifically.


CANDIDATE GATE POSTURES
========================

(A) STRICT — Agent must run automated Ruby 2.2.4 syntax check
    before final Gate, IN ADDITION to Owner SU2017 verification.

    How: Agent finds a Ruby 2.2.4 binary (or compiles from source —
    ruby/ruby/ruby on GitHub tags). Cost: maybe 30-60 min download
    + boot. Lockfile-compatible with our existing 2.7.8 isolation.

    Pros: literally satisfies "Ruby 2.2.4 / SU2017 的语法与目标环境证据".
    Cons: extra work; Ruby 2.2.4 binaries are scarce on modern Windows
    (only the SU2017-bundled interpreter and a few old rubyinstaller
    builds exist).

(B) PRAGMATIC — Owner real-SU verification on SU2017 IS the
    2.2.4 baseline evidence. Agent just needs static check + the
    Owner SU2017 PASS to close Q004. [Agent default]

    Rationale: SU2017 ships with Ruby 2.2.4 built-in. If Owner
    loads our extension into SU2017 and it runs without syntax
    error AND all 33 synthetic tests conceptually hold (via the
    Snapshot Builder + PreflightRunner paths), that IS Ruby 2.2.4
    target environment evidence. We don't need a separate bare
    Ruby 2.2.4 install.

    Pros: zero extra Agent work; reuses the Stage 2 Owner verification
    flow (just add "run on SU2017, not just your daily version").
    Cons: depends on Owner having / installing SU2017. If Owner
    only has SU2024, we have indirect evidence at best.

(C) DEFERRED — Acknowledge in TASK 001 IMPLEMENTATION REPORT that
    Q004 caveat is open; mark as "Ruby 2.2.4 runtime evidence
    pending — see Owner follow-up". Ship anyway.

    Pros: unblocks Gate; lets Owner schedule SU2017 verification
    on their timeline.
    Cons: violates the literal reading of Q004 ("在最终 Gate 前,
    仍需补充 ... 证据"). Code review (Codex) may reject.


AGENT'S RECOMMENDATION
======================

Pick B. It's the literal interpretation of "SU2017 的语法与目标环境
证据" — SU2017's bundled interpreter is Ruby 2.2.4 by definition,
so an Owner run on SU2017 is direct 2.2.4 evidence.

If Owner doesn't have SU2017 installed (only SU2024 or newer), the
caveat remains open. Then either:
  - Install SU2017 trial alongside current SU (free, both can
    coexist; SU keeps per-version app data)  → ~30 min
  - Switch to posture (A) — Agent finds Ruby 2.2.4 binary separately
  - Switch to posture (C) — defer


QUESTIONS FOR OWNER
====================

Q4.1  Gate posture pick:  A / B / C  → default B.

Q4.2  If B: do you have SU2017 installed?  Y / N / "I'll install it".

Q4.3  If B and you have SU2017:
       Can you run the Stage 2 OWNER_VERIFICATION_STAGE_2.txt
       checklist on BOTH your daily SU version AND on SU2017?
       (Doubles the verification cost, but closes both Stage 2
       AND Q004 in one pass.)


NO REPLY = POSTURE B WITH THE CAVEAT THAT IF OWNER LATER DECIDES
SU2017 IS NOT AVAILABLE, AGENT WILL PIVOT TO POSTURE A.

============================================================
END
============================================================
