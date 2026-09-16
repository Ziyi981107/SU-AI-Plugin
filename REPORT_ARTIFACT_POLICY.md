# SU-AI-Plugin — REPORT ARTIFACT POLICY

Date: 2026-09-16
Status: ACTIVE — DURABLE GOVERNANCE OVERRIDE
Authority: Owner + ChatGPT / AIPM

## 0. Purpose

Keep routine implementation/review evidence out of tracked project history while preserving direct source review and durable project truth.

This policy is authoritative for report/review artifact placement. Where older text in `AGENTS.md`, `PROJECT_HANDOFF.md`, historical Prompt files, or historical Review files says routine Pi/AIPM reports must be written under `Review/`, this policy supersedes that placement rule.

It does NOT change product architecture, Stage boundaries, source authority, test gates, or Git branch policy.

## 1. Routine Pi return channel

The normal Pi implementation report is now:

`output/CURRENT_PI_REPORT.md`

Rules:

- local working artifact only;
- `output/` is gitignored;
- MUST NOT be added, committed, or pushed;
- may be overwritten each dispatch;
- Owner may upload/share it with AIPM when useful;
- AIPM does not rely on it as source truth and performs direct Git/source/diff review.

Pi's terminal completion summary must still include at minimum:

- implementation SHA;
- final remote HEAD;
- exact changed production/test files;
- focused/regression/full-runner summary;
- any known pre-existing failures separated from new regressions;
- STOP / control returned to AIPM.

## 2. Review/ directory

`Review/` is now a HISTORICAL / DURABLE-EVIDENCE archive, not the normal return channel.

Pi MUST NOT create, prepend, replace, or update routine files under `Review/`.

Existing historical Review files remain in Git and are not deleted merely to clean history.

A new tracked Review artifact is allowed ONLY when the current AIPM dispatch explicitly authorizes a durable long-term evidence record, for example:

- mandatory Codex Gate result;
- Owner verification / acceptance record;
- Stage closure;
- release report;
- material risk acceptance.

Absent explicit authorization, Review is read-only for Pi.

## 3. Routine AIPM review

AIPM's normal primary review is direct source/diff review plus the current conversation. A routine AIPM verdict does not need `Review/CURRENT_AIPM_REVIEW.md`.

Durable AIPM/Codex/Owner Gate evidence may be tracked only when long-term reference is justified.

## 4. Canonical tracked files

Routine tracked project truth remains:

- `CURRENT_STATE.md`
- `Prompt/CURRENT_PI_DISPATCH.md`
- durable AIPM Blueprint / Guidance when justified
- source / tests / package scripts
- Git history

Routine report verbosity belongs in `output/`, not tracked Git history.

## 5. Completion rule

For a normal ACTIVE dispatch Pi:

1. implements/tests inside the frozen contract;
2. updates `CURRENT_STATE.md` only with concise current project truth;
3. writes/replaces `output/CURRENT_PI_REPORT.md` locally;
4. does NOT touch `Review/` unless the dispatch explicitly authorizes durable evidence;
5. commits only authorized tracked source/test/state/governance artifacts;
6. pushes only the assigned `dev/vX.Y` branch;
7. prints the terminal completion summary;
8. STOPs and returns control to AIPM.

END
