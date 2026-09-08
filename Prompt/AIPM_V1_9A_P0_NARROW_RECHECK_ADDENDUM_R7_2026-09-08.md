# AIPM V1.9A P0 NARROW RECHECK — R7 ADDENDUM

Project: SU-AI-Plugin
Stage: V1.9A — Final Block Fix
Date: 2026-09-08
Authority: ChatGPT / AIPM
Final Product Owner: Owner
Implementation Agent: Pi
Target branch: `dev/v1.9`
Status: AUTHORITATIVE NARROW ADDENDUM
V1.9B: NOT AUTHORIZED / NOT STARTED

This addendum supplements:

- `Prompt/AIPM_V1_9A_P0_NARROW_RECHECK_FIX_2026-09-08.md`
- `Review/CURRENT_AIPM_REVIEW.md`

It adds one newly discovered presenter regression only. All R1–R6 guidance remains unchanged.

---

# R7 — RESTORE `deep_nesting` CURRENT-ATTENTION CHIP SEMANTICS

File:

`extension/su_ai_plugin/cad_prep_workflow_presenter.rb`

## Source-review finding

The baseline presenter included `嵌套层级` in `PROBLEM_METRIC_LABELS`.

The current P0 implementation accidentally removed that label during the mojibake/CRLF recovery pass, while `_other_issue_label('deep_nesting')` still returns `嵌套层级`.

Current `_is_problem_metric?` returns true only for labels in `PROBLEM_METRIC_LABELS`; therefore a current `deep_nesting` secondary issue can still make the `other` card REVIEW_REQUIRED but its metric is omitted from the primary current-attention chips / issue headline total.

This is a truthfulness regression and was not an intended product change.

## Required correction

Restore exactly:

```ruby
嵌套层级
```

inside `PROBLEM_METRIC_LABELS`.

Do not redesign the issue taxonomy, `_other_issue_label`, current Issues semantics, badge semantics, or app.js.

## Required regression

Add the narrowest presenter test proving:

- `analysis_summary['issues']['deep_nesting'] = N > 0` produces the `other` card metric `{ value: N, label: '嵌套层级' }`;
- `_collect_chips` / the resulting current issue summary includes that `嵌套层级` metric as current attention;
- CLEAN/APPLIED success metrics remain excluded.

## Scope

This correction is already inside the current narrow presenter allowlist.

No other production file is authorized by this addendum.

---

END
