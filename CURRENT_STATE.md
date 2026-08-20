# CURRENT STATE

Last updated: 2026-08-20 (V1.1 implementation COMPLETE.
All 5 commits landed on `v1.1-layer-semantic-mapping` branch
(head = `823feab`). Full suite 372/372 PASS, 0 fail, 0 error.
V1.1 Owner Gate 2 checklist drafted at
Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt.
Awaiting Owner real-SU2020 Gate 2 V1.1 verification, then
CodeX end-of-stage review per plan §13. V1.0 candidate still
FROZEN at tag `v1.0-candidate-2026-08-19` (commit `56ea611`).
Gate 1 (SU2017) PENDING per R006 — deferred to formal release.)

## Agent hand-off status (2026-08-20)

The Agent has entered the **WAIT-FOR-OWNER-GATE-2-V1.1** phase.
Implementation is COMPLETE on `v1.1-layer-semantic-mapping`
(head = `823feab`, 372/372 PASS). No further code changes are
scheduled unless Owner reports a real-SU2020 regression in the
Gate 2 V1.1 verification.

  - **Owner right now**: run
    `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt`
    L1..L9 on real SU2020. Drop the report at
    `Prompt/OWNER_REPORT_V1_1_LAYERS_2026-08-XX.txt`.
  - **Agent right now**: idle on Owner action. On Owner PASS,
    Agent assembles ONE consolidated CodeX end-of-stage review
    packet per V1.1 plan §13 (NOT before; NOT a re-review of
    V1.0 / Stage 6 / CodeX 020 / RBZ / CodeX 024).
  - **Out of scope until Owner reports**: CodeX end-of-stage
    packet, formal release, Gate 1 (SU2017, deferred to formal
    release per R006), and any V1.1 / V1.0 scope re-opening.

Independent Agent-side finishing work (committed in this
session, no behavior change):

  - Whitespace / encoding audit on `CURRENT_STATE.md`: file is
    clean (no trailing whitespace, no NBSP / ZWSP / BOM). The
    pre-crash session's line-122 grep investigation did not find
    a real defect; line 122 is just the natural markdown
    soft-wrap of the surrounding paragraph.
  - `data/_check_tmp/` audit: all WIP files are already isolated
    (`data/_check_tmp/` is `.gitignore`d AND listed in
    `scripts/build_rbz.rb EXCLUDED_TOP_LEVEL`). RBZ shipping is
    confirmed WIP-free. Recent one-shot debug files
    (`_check_whitespace.rb`, `debug_layer_groups.rb`) removed.
    Older `_WIP_*` historical artifacts left in place as audit
    trail (gitignored, no shipping risk).
  - `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt` L5
    title typo (`EMHASIS` → `EMPHASIS`) corrected so Owner can
    read step titles without confusion.
  - Full suite re-run: **372/372 PASS, 0 fail, 0 error**
    (V1.0 baseline 286 + V1.1 additions 86 unchanged).
  - Stable Git checkpoint committed: only documentation,
    cleanup, and test-stabilization changes; no production
    code, no API contract, no V1.0 / V1.1 scope.

## Active baseline (V1.0, head of `main` = 56ea611)

- V1.0 candidate is **frozen** for release decisions. Do not mix
  V1.1 / next-stage work into this baseline without re-running
  Gate 2 + Gate 1 on the resulting RBZ.
- Stage 6 owner verification: PASS (K..N real-SU2020, including
  closed group / duplicate component / deep nesting / dangling
  edge).
- Gate 2 install: PASS (dist/SU-AI-Plugin.rbz installed on
  SU2020, Owner verbal confirm recorded in
  Review/OWNER_VERIFICATION_RBZ_INSTALL_2026-08-19.txt).
- RBZ package + root loader structure: PASS (CodeX Review 024
  recheck closed BLOCK-022-001 and BLOCK-023-001/002).
- Real-host fixes closed this week: REAL-HOST BLOCK (to_a +
  variable-shadow), K2 duplicate-component crash
  (IssueNormalizer private/module_function), L3 non-locatable
  warning (renderIssue click-handler gate). All 286 tests PASS,
  all evidence in the lower sections of this file.

## V1.1 stage (IMPLEMENTATION COMPLETE on
            `v1.1-layer-semantic-mapping` branch, head = `823feab`)

- **Implementation status**: **ALL 5 commits landed**; full
  suite 372/372 PASS, 0 fail, 0 error. V1.0 baseline (286
  tests) UNCHANGED; 86 V1.1 additions (Layer role + config +
  record + source ref, mapper, grouper, su_capability visibility,
  AnalyzersRunner integration, UIBridge layerGroups, full UI
  render for Layers section).
- **Decision (Cicada 2026-08-19)**: V1.1 first stage is
  **Layer Semantic Mapping** — read-only classification of each
  layer into a role (:construction / :dimension / :annotation /
  :guide / :unknown), surfaced in a new "Layers" section of
  the dialog. Visibility is a SEPARATE field, NOT a role
  (R007 / ChatGPT §11.3).
- **Plan**: `Review/V1_1_LAYER_SEMANTIC_MAPPING_PLAN_2026-08-19.md`
  (FINAL, 864 lines).
- **Progress report**: `Review/V1_1_LAYER_SEMANTIC_MAPPING_PROGRESS_2026-08-19.md`
  (updated 2026-08-20 with all 5 commits + RBZ rebuild + L1..L9
  checklist handoff).
- **Owner checklist (Gate 2 V1.1)**:
  `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt`. Steps
  L1..L9 cover V1.0 baseline + 8 V1.1-specific checks + a
  byte-identical PRE/POST fingerprint.
- **Reviewer routing** (per Cicada 2026-08-19 routing rule):
  1. **ChatGPT** answered §11 — 10 plan-level policy / UX /
     fail-closed / sort-order questions. **ALL ANSWERED.**
  2. **Agent self** decided §12 — 2 contained code-architecture
     questions with documented defaults (SourceReference
     extension; first-seen-wins dedup).
  3. **Agent** implemented per the answers + defaults (5/5
     commits landed).
  4. **CodeX** end-of-stage review of the full V1.1
     implementation diff (§13), awaiting Owner Gate 2 V1.1
     evidence.
- **Locked V1.1 decisions** (all incorporated into the implementation):
  - **R007** (ChatGPT §11.3): role and visibility are SEPARATE
    fields. The `OFFSCREEN` role Symbol is REMOVED. 5 name-based
    roles only.
  - **R008** (ChatGPT §11.7): no role color hints in V1.1.
    Roles use text + neutral badge. V1.0 issue severity palette
    is NOT reused for roles.
  - **R009** (ChatGPT §11.2): layer display order = role
    order, hidden layers LAST within each role bucket (with
    `opacity: 0.6` muted style).
  - **R010** (ChatGPT §11.8): rule ordering is top-down-by-
    priority. NOT auto-promoted by specificity. Specificity
    may be a future tie-break / lint hint, not the main rule.
    Test pin: a layer matching two rules gets the FIRST rule's
    role.
  - **R011** (ChatGPT §11.9): `layer_visibility` returns
    `:visible | :hidden | :unknown` Symbol. The caller maps
    `:unknown` to `LayerRecord(visible: true, visibility_unknown:
    true)` — operational fallback is visible, but the data
    model preserves the uncertainty. UI surfaces a third
    badge "Visibility: unknown". We do NOT fake `false`
    ("confirmed hidden") when the answer is "I don't know".
  - **R012** (ChatGPT §11.10): layer role order is INDEPENDENT
    from `IssueRegistry::DEFAULT_GROUP_ORDER`. Locked as
    `[dimension, annotation, guide, construction, unknown]`.
    Issue type and semantic role are two different information
    systems.
  - Layers section BELOW per-issue-type groups (ChatGPT §11.1).
  - Layers `<details>` default-closed, summary shows
    `"Layers — N total (M with issues)"` (ChatGPT §11.5).
  - `:unknown` role retained, surfaced as "Unknown / ?"
    (ChatGPT §11.6).
  - Per-layer `edge_count` + `issue_count` both shown,
    `issue_count` visually emphasized when > 0 (ChatGPT §11.4).
- **Branch state**: `v1.1-layer-semantic-mapping` cut from
  `v1.0-candidate-2026-08-19` at commit `56ea611`. **5 code
  commits landed** as of this report (head = `823feab`):
  ```
  823feab feat(v1.1): UI render for Layers section + locked L4 DOM/CSS/JS contract (commit 5)
  ef9ae04 feat(v1.1): AnalyzersRunner.layer_groups + UIBridge.layerGroups (commit 4)
  4e626d3 feat(v1.1): SUCapability.layer_visibility + preflight layer population (R007/R010/R011)
  a2b05df feat(v1.1): LayerSemanticMapper + LayerIssueGrouper (pure Ruby)
  460037c feat(v1.1): pure Ruby layer data layer + V1.1 extension to existing records
  ```
  `dist/SU-AI-Plugin.rbz` rebuilt locally at end of commit 5
  (214,776 bytes, 41 entries; gitignored). `git diff --check`
  clean on all 5 commits.
- **Hard scope** (inherited from V1.0 + R006 = Gate 1 deferred):
  - Read-only analysis, no model mutation, no new SU API beyond
    `Layer#visible?`.
  - V1.0 tests (286) MUST still pass unchanged. **VERIFIED: all
    286 V1.0 tests pass on the V1.1 branch head.**
  - Gate 1 (SU2017) remains PENDING per R006; not a V1.1 blocker.
  - Gate 2 V1.1: Owner re-runs the V1.0 checklist PLUS V1.1
    Layers-specific checks on real SU2020 before V1.1 is
    considered ready. **Checklist drafted at
    `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt`; awaiting
    Owner run.**
- **Next action** (post-implementation):
  1. **Owner Gate 2 V1.1** — run
     `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt` steps
     L1..L9 on real SU2020. Owner drops report to
     `Prompt/OWNER_REPORT_V1_1_LAYERS_2026-08-XX.txt`. Once Owner
     reports PASS, V1.1 stage is accepted on the verified host.
  2. **CodeX end-of-stage review** — Agent dispatches ONE
     consolidated packet per plan §13 (this branch's full diff
     `56ea611`..`823feab` + 372/372 test results + Gate 2 V1.1
     Owner report + §12 defaults + §8 known risks). CodeX engages
     ONLY at this boundary; reopening V1.0 Stage 6 / CodeX 020
     / RBZ / CodeX 024 is explicitly out of scope.
  3. **Formal release** — Owner combines V1.0 + V1.1 in the
     final .rbz artifact, reruns Gate 1 (SU2017) + Gate 2 V1.1
     on the combined artifact, and ships. Per R006, Gate 1 is
     deferred to formal release.

## Migration tail (commits 8814455, b0c16c8)

- `8814455 chore(structure): finalize V1.0-candidate package-structure
  migration` — removes the 24 legacy root-level `core/*` and
  `compatibility/*` files that were duplicated at
  `extension/su_ai_plugin/{core,compatibility}/` since 7b722b9
  (RBZ standard contract commit).
- `b0c16c8 chore(scripts): add stop_monitor.ps1 helper` — adds
  the missing workflow companion to the already-tracked
  `prompt_monitor.ps1` / `restart_monitor.ps1` /
  `check_monitor.ps1` / `prompt_monitor_one_shot.ps1`.
- These are pure cleanup, no product-scope, no compatibility,
  no release-promise changes. No Codex review was triggered;
  ordinary implementation decision per the handoff protocol.

## Open / pending (NOT in scope to act on now)

- **Owner Gate 2 V1.1 verification** (current next action):
  Cicada runs `Review/OWNER_VERIFICATION_V1_1_LAYERS_2026-08-20.txt`
  L1..L9 on real SU2020. Per Q002=A, only Owner can run real-SU
  verification. Once Owner drops the report at
  `Prompt/OWNER_REPORT_V1_1_LAYERS_2026-08-XX.txt`, the V1.1
  stage moves to accepted-on-SU2020.
- **CodeX end-of-stage review** (next code action after Owner
  Gate 2 V1.1 PASS): one consolidated packet per V1.1 plan §13.
  CodeX is reserved for: complete coherent stage (the V1.1
  implementation IS that), high-risk blocker, BLOCK recheck,
  final release review. Reopening V1.0 scope is explicitly out
  of scope for this packet.
- **Gate 1 (SU2017 minimum-host verification)**: PENDING. Cicada
  (2026-08-19) has chosen to defer this until formal release.
  Per R004 + R006 posture, this is a final release gate and
  MUST be repeated on whatever RBZ is shipped. Do not block
  V1.1 acceptance on this; do not fake SU2020 evidence as SU2017
  evidence.
- **V1.1 LayerIssueGrouper integration into the UI**: the
  commit-2 pure-Ruby grouper (`core/layer_issue_grouper.rb`)
  exists but is not yet consumed by any UI surface. It is a
  forward-compatibility hook for a future V1.1.1 stage that
  wants an "Issues by Layer" <details> block. Per plan §4.5
  the API is locked; the UI integration is intentionally
  deferred. NOT a V1.1 blocker.
- **CodeX review cadence**: Pi's handoff is explicit — do NOT
  submit tiny edit packets, partial packets, or progress pings.
  Codex is reserved for: complete coherent stage, high-risk
  blocker, BLOCK recheck, final release review. Routine coding
  decisions stay with the agent.

## 决策落地 (PI_TASK_001)

| ID | Decision | 状态 |
|---|---|---|
| Q001 git workflow | **B** — 本地 git init, 不 push, 阶段 commit | ✅ 已在用 |
| Q002 real SU verification | **A** — Owner 在真 SU 跑, Agent 写代码 + 清单 | ✅ 按此推进 |
| Q003 target SU version | **A** — **SU2017+ 硬基线, Ruby 2.2.4** | ✅ 已修正 |
| Q004 Ruby in Agent env | **C** — 隔离运行时, 真实跑 tests | ✅ DONE |

## 重要事实纠正 (per Codex 2026-08-14)

- ❌ 旧假设 (Stage 0 那轮写的): "Ruby 2.4+", "Q003=B (SU2018+ 基线)"
- ✅ 正确: **SU2017+**, **Ruby 2.2.4** 是硬最低基线
- ✅ `Sketchup::Entity#persistent_id` 在 **SU2017 起就有**, 不是 SU2018+ 才有
- ✅ capability detection (`respond_to?`) 优先于版本号判断

## CODEX REVIEW 009 (2026-08-17) — VERDICT: PASS (BLOCK recheck 4)

CODEX_REVIEW_009 (BLOCK recheck 4, commit 9ff2e49 + recheck packet):
  VERDICT: PASS
  ALL BLOCKS CLOSED:
    S2-BLOCK-001                CLOSED
    S2-BLOCK-002                CLOSED  (real API contract accepted)
    S2-BLOCK-003                CLOSED
    S2-BLOCK-004                CLOSED  (adjacent-bucket dedup accepted)
    S2-BLOCK-005                CLOSED  (checklist H correction accepted)
    S2-BLOCK-006 HtmlDialog     CLOSED
    S2-BLOCK-006 version         CLOSED  (dotted diagnostic + major)

  Stage 2 implementation BLOCK-checks PASSED. This is NOT a release
  verdict and NOT a substitute for real-host evidence.

  Owner should now execute Review/OWNER_VERIFICATION_STAGE_2.txt
  steps A-I in real SketchUp. SU2017 required to close R004 caveat.
  Owner drops report to Prompt/OWNER_REPORT_STAGE_2_<date>.txt.

## CODEX REVIEW 008 (2026-08-17) — BLOCK recheck 3 result

CODEX_REVIEW_008 (BLOCK recheck 3, commit 88ad609 + recheck packet):
  S2-BLOCK-002  CLOSED  (real API contract accepted)
  S2-BLOCK-004  CLOSED  (adjacent-bucket dedup accepted)
  S2-BLOCK-006 version subpart  CLOSED  (dotted diagnostic + major)
  S2-BLOCK-005  REMAINS OPEN  (only checklist H selection shape has
                              overlap; traversal itself OK)
  S2-BLOCK-001 + S2-BLOCK-003 + S2-BLOCK-006 HtmlDialog  still CLOSED

NEXT: 修 S2-BLOCK-005 checklist H (selection_array 去掉 e2_valid),
加 1 个自动化测试用修正后的形状。

## CODEX REVIEW 007 (2026-08-17) + GUIDANCE 006 — BLOCK recheck 2 result

CODEX_REVIEW_007 (BLOCK recheck 2, commit d7ac371 + Review recheck packet):
  S2-BLOCK-001  CLOSED  (still)
  S2-BLOCK-003  CLOSED  (still)
  S2-BLOCK-006 HtmlDialog subpart  CLOSED  (namespace fix accepted)
  S2-BLOCK-002  REMAINS OPEN  (real API contract issues)
  S2-BLOCK-004  REMAINS OPEN  (boundary-bucket dedup)
  S2-BLOCK-005  REMAINS OPEN  (checklist + invalid geometry)
  S2-BLOCK-006 version subpart  REMAINS OPEN  (version_number not calendar year)

CODEX_GUIDANCE_006 (plan corrections, MANDATORY):
  1. Version API: sketchup_version to_s for diagnostics; baseline
     `Sketchup.version.to_i >= 17`. NO calendar-year inference from
     version_number.
  2. Active edit context: use model.edit_transform; model.active_path
     is Array (NOT InstancePath); resolver takes dot-delimited String.
  3. Vertex dedup: search current + adjacent buckets; preserve
     5000-Edge perf target.

NEXT: pass-3 rework incorporating CODEX_GUIDANCE_006 corrections.
Closed scopes stay closed (S2-BLOCK-001, S2-BLOCK-003, S2-BLOCK-006
HtmlDialog).

## CODEX REVIEW 005 (2026-08-17) — VERDICT: PARTIAL PASS, 4 BLOCKS remain

Codex did focused recheck (Commit eb3cd41) for S2-BLOCK-001..005.
Result:
  S2-BLOCK-001  CLOSED  (one Edge -> one EdgeRecord confirmed)
  S2-BLOCK-003  CLOSED  (no &. in production entry path)
  S2-BLOCK-002  REMAINS OPEN  (3 sub-issues)
  S2-BLOCK-004  REMAINS OPEN  (3 sub-issues + perf)
  S2-BLOCK-005  REMAINS OPEN  (5 sub-issues)
  S2-BLOCK-006  NEW BLOCK   (capability probe uses wrong namespace)

Plus NITs:
  - SourceReference instance_path mutability inconsistency
  - Recheck packet told Owner to verify before recheck PASS (should pause)

NEXT: focused rework on S2-BLOCK-002 / 004 / 005 / 006 only.
S2-BLOCK-001 / -003 stay closed.

## CODEX REVIEW 004 (2026-08-17) — VERDICT: BLOCKED on Stage 2 SU adapter

Codex reviewed Stage 2 commit 6eb33e8. Pure-Ruby 33/33 tests PASS evidence
remains valid for the paths it exercises. The SketchUp traversal / snapshot
adapter is BLOCKED with 5 BLOCKS — see Review/CODEX_REVIEW_004_BLOCK_REWORK_PLAN.md
(queued for next session).

5 BLOCKS:
  S2-BLOCK-001  Every SketchUp Edge becomes 2 EdgeRecords (doubling).
  S2-BLOCK-002  Component traversal, accumulated transforms, instance-aware
                identity missing in extension/preflight_runner.rb.
  S2-BLOCK-003  &. safe-navigation operator used (post Ruby 2.3, violates
                Ruby 2.2.4 baseline).
  S2-BLOCK-004  Preflight metrics do not match task contract (non-zero-Z
                counts, nesting level semantics, severity canonicalization).
  S2-BLOCK-005  Owner verification checklist has invalid API setup paths
                and weak source-integrity check.

CURRENT_STATE label correction (Codex NIT):
  Stage 2 is NOT 'DESIGN PASS'. It is: 'pure-Ruby Preflight tests pass;
  SU adapter blocked / rework required'. Fixed below in section labels.

R001-R005 are all ANSWERED (Codex decisions documented in each R### file
per WORKFLOW_PROTOCOL). All 5 R### files updated to Status: ANSWERED.

## 已完成 (Stage 0 + Stage 1)

### Stage 0 — 仓库骨架
- `git init -b main` (本地, 不 push)
- `.gitignore` (SU/CAD/编辑器/OS/Ruby)
- `README.md` + `CURRENT_STATE.md`
- 自建 `tests/runner.rb` + `tests/run_all.rb` (零 gem 依赖)

### Stage 1 — 纯 Ruby Geometry Core (代码已就位 + 实跑通过)
- 数据模型: `Tolerance / SourceReference / EdgeRecord / VertexRecord /
  LayerRecord / AnalysisConfig / GeometrySnapshot`
- 空间索引: `QuantizeKey / VertexIndex`
- 4 个 Analyzer: `DuplicateDetector / ShortEdgeDetector /
  OpenEndpointDetector / GapCandidateDetector`
- `SyntheticFactory` 测试 fixture 构造器 (已从 class 改为 module)
- `Tests.run!` 测试 dispatcher (Stage 1 PASS commit `5e32ab1` 补齐)
- Synthetic Tests TC-01..TC-10 + 数据模型 + 容差边界 + issue 字段
  完整性测试, 总共 26 个 `test` cases
- 代码风格: Ruby 2.2.4-safe (无 pattern matching / numbered params /
  endless method / kwargs 糖 / frozen_string_literal magic)
- ✅ 隔离 Ruby 2.7.8 实跑: 26/26 PASS

### Stage 2 — Preflight (pure-Ruby 部分 PASS, SU 端 BLOCKED / rework 待执行)
**纯 Ruby 部分 (Agent 已实跑通过):**
- `core/tolerance.rb` 新增 2 字段: `big_z` (默认 0.01 in),
  `large_coordinate` (默认 1e6 in)
- `core/analysis_config.rb` 增加 passthrough `big_z` / `large_coordinate`
- `core/preflight.rb` NEW: `PreflightReport` 数据类 +
  `PreflightAnalyzer` 纯 Ruby 聚合器 (无 Sketchup:: 调用)
- `tests/test_preflight.rb` NEW: TC-11..TC-15 + 2 EXTRA = 7 cases
- 7/7 PASS

**SU 端部分 (Agent 设计完毕, Owner 在真 SU 验证):**
- `compatibility/su_capability.rb` NEW: capability 检测 shim
  (`sketchup_version`, `supports_persistent_id?`, `safe_persistent_id`,
   `edge?` / `group?` / `component_instance?` / `container?`,
   `layer_name`, `build_source_reference`)
- `extension/preflight_runner.rb` NEW: SU 端入口,
  从 `Sketchup::Selection` 递归 Group/Component 收集 Edges → 建
  GeometrySnapshot → 跑 PreflightAnalyzer → PreflightReport。
  §18 错误处理: 异常 Entity `warn` 后跳过, 不让分析崩
- `Review/OWNER_VERIFICATION_STAGE_2.txt` NEW: 9 步 (A..I) Owner 手动
  验证清单 (plugin load / capability / 各 preflight 字段 / 不改源 CAD /
  错误处理 / perf)

## Stage 1 自测状态 (Q004=C) — 2026-08-17 PASS

- ✅ 隔离 Ruby 运行时已落地: `.vendor/ruby/rubyinstaller-2.7.8-1-x64/`
  - 来源: GitHub mirror `ghfast.top` (直接 GitHub 在本环境下 10s 超时,
    `github.akams.cn` / `gh-proxy.com` 亦可用作 fallback)
  - 体积: 7z 包 12.17 MB, 解压后 90 MB, 含 `bin/ruby_builtin_dlls/`
    (缺这部分则 `ruby.exe` 会报 SxS 错误, 上一轮 `C:\Ruby27-x64\`
    安装不完整的原因就是这个 DLL 集合未提取)
  - 调用: 全程绝对路径 `.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`,
    不入 PATH, 不入 Git (`.vendor/` 已被 `.gitignore` 排除)
- ✅ 实跑 `tests/run_all.rb`: **33 tests: 33 pass, 0 fail, 0 error**
  - 完整 log: `.vendor/STAGE_1_TEST_RUN_2026-08-17.log`
  - Ruby 版本证据: `.vendor/RUBY_VERSION_2026-08-17.txt`
  - 覆盖: 16 data-model + 7 preflight + 10 synthetic TC-01..TC-10
- ✅ Stage 1 stable checkpoint commit `5e32ab1`
- ⚠️ **Q004 旁注 (caveat, 不阻碍进入下一阶段)**:
  - 实际跑测试的是 Ruby 2.7.8p225, 交付代码最低基线是 Ruby 2.2.4 (SU2017 内置)
  - 静态检查 Stage 1 + Stage 2 代码已经按 2.2.4-safe 写
  - 真实 2.2.4 baseline 证据 **仍需** 在最终 Gate 前补 (Owner 真 SU 验证
    跑 SU2017 即满足此 caveat, 不必单独找 2.2.4 二进制)

## 调试期顺手修的 bug

### Stage 1 (commit 5e32ab1)
- `core/synthetic_factory.rb`: `class SyntheticFactory` → `module SyntheticFactory`
  (原版 `class` + `module_function` 是语法错误, 上一轮没跑过测试所以没暴露)
- `tests/runner.rb`: 补上 `Tests.run!(filter=nil)` 方法
  (上一轮写了 TestCase/TestResult 但漏了 dispatcher, 调用 `Tests.run!` 会
  NoMethodError)

### Stage 2 (本轮, 跟 Stage 2 一起 commit)
- `tests/runner.rb` 加 3 个 helper: `assert_nil` / `refute_nil` / `assert_operator`
- `core/tolerance.rb` 加 `big_z` / `large_coordinate` 字段 + 默认值
  (向后兼容: 新字段有默认值, 不改现有 Profile 序列化路径)
- `core/analysis_config.rb` 加 passthrough, 让 PreflightAnalyzer 写
  `config.big_z` 而不是 `config.tolerance.big_z`
  (后续重命名 Tolerance 字段时不需跳 Preflight)

## Next Step (Phase G — Stage 2 BLOCK-checks COMPLETE, awaiting Owner real-SU verification)

1. ✅ **已结束** — Q001-R005 全部 ANSWERED, BLOCKED 现状反映到 CURRENT_STATE
2. ✅ **已结束** — Codex Review 004 BLOCK rework pass 1
   (commit `eb3cd41`): S2-BLOCK-001 + S2-BLOCK-003 CLOSED; 50/50 PASS
3. ✅ **已结束** — Codex Review 005 BLOCK recheck + pass 2 rework
   (commits `fd0a0ab`, `d7ac371`): S2-BLOCK-001/003 stay CLOSED;
   S2-BLOCK-006 HtmlDialog CLOSED; 65/65 PASS
4. ✅ **已结束** — Codex Review 007 BLOCK recheck 2 + GUIDANCE 006
   plan corrections received (最新 Prompt/)
5. ⏳ **下一步 (本轮)** — pass 4 final 修 S2-BLOCK-005 checklist H
   selection_array 修正 + 1 自动化测试 (生产 traversal 不动)
   CODEX_GUIDANCE_006 三条修正:
   - Version API: sketchup_version 保留 String 诊断;
     baseline = `Sketchup.version.to_i >= 17`; 不从 version_number 推日历年
   - Active edit context: model.edit_transform + active_path 是 Array;
     resolver 接收 dot-delimited String
   - Vertex dedup: 扫当前 + 邻接 buckets; 保留 5000-edge perf
   见 `Review/CODEX_REVIEW_007_BLOCK_REWORK_PLAN.md`
6. **BLOCK recheck 3 PASS 后** — Owner 跑真 SU 验证 (Q002=A) +
   走 R004 posture B (SU2017 必须)
7. **Stage 6** — UI (per R003 + R005)
8. **Stage 7** — TASK 001 IMPLEMENTATION REPORT (PI_TASK_001 §22)
9. **最终 Gate 前** — Ruby 2.2.4 / SU2017 真机证据 (R004 posture B)


## Stage 2 设计边界 (NOT IN SCOPE, 明确不做, per PI_TASK_001 §17)

本阶段禁止实现：

- 自动删除重复线、Gap 自动连接、Flatten、Weld、Polyline reconstruction、
  Closed Loop reconstruction、Face generation、道路识别、建筑识别、
  Layer semantic mapping、AI、MCP、场地生成、住宅生成、自动 CAD import、
  完整 settings UI、云服务。

如果发现这些需求: 记录 TODO, 不要顺手做。

## 已知问题 / Lessons

### Lesson — review assumption vs hard constraint
- Stage 0 那轮把 Q003 默认假设成 "SU2018+ / Ruby 2.4+", 用 "更现代" 为由
  默认升级产品基线, 这是错的。
- Owner 决策 #004 已经锁定 SU2017+ 硬基线, Agent 不应擅自决定。
- 后续: **凡是涉及产品 / 兼容基线 / 用户级行为 的决策, 一律上 Review**,
  不在 "技术细节" 的掩护下随手定。

### Lesson — install system Ruby is wrong direction
- 之前想装系统 RubyInstaller 是错路。
- 正确做法: 隔离运行时 (`.vendor/` 或 temp), 不污染 PATH, 跑完可删。
- 这条 lesson 跨项目价值高, 已经写到 Q004 IMPACT 段供 Codex / AIPM 审。

### Lesson — isolated 7z bundle needs ruby_builtin_dlls/
- 直接用 RubyInstaller-3.x .exe 在 Windows 7z 提取会缺 `x64-msvcrt-rubyNNN.dll`
- 选 .7z bundle + standalone 7zr.exe 是稳的; 前提是 bundle 含 `ruby_builtin_dlls/`
- RubyInstaller 2.7.8 .7z bundle 自带; 这是为什么本次 C:\Ruby27-x64\ 装出来
  ruby.exe 跑不了 (上一轮用了 rubyinst.exe self-extracting installer, 那个不走
  7z 提取路径, 也没走 Inno Setup, 落得不完整)
- 跨项目可复用: Windows 下跑 Ruby 的最小可用姿势 = `.7z` bundle +
  standalone 7-Zip, 不要 `.exe`

### Code — 无已知 block
- Stage 1 + Stage 2 纯 Ruby 部分: 33/33 PASS
- Stage 2 SU 端: 设计完毕, 等 Owner 验证

## CODEX REVIEW 018 (2026-08-18) �� GATE B RECHECK: ALL 6 BLOCKs CLOSED

**Verdict**: All 6 S6-GATE-B-BLOCK-001..006 closed in one consolidated
rework. Full test suite: 244/244 PASS, 0 fail, 0 error.

### Code-side changes
- `extension/analyzers_runner.rb`: removed the second `diagnostics = []`
  that wiped per-analyzer failure entries (BLOCK-005). Same `diagnostics`
  array now flows from the analyzer rescue -> IssueRegistry -> AnalysisResult.
- `extension/su_ai_plugin.rb` (new): real SketchUp boot entrypoint
  with `file_loaded?` / `file_loaded` guard + safe `require_relative`
  chain + `Loader.register!` exactly once (BLOCK-002).
- `extension/loader.rb`: register! uses a module-level `@registered`
  sentinel (NOT menu introspection) for idempotency; holds the live
  dialog reference in `@live_dialog`; on_analyze_selection propagates
  `model` into `DialogRunner.show` (BLOCK-002, BLOCK-004, BLOCK-006).
- `extension/dialog_runner.rb`: model flows through to DialogController;
  on_locate emits `window.SUAIP.toast(...)` on unresolved (BLOCK-003,
  BLOCK-004).
- `extension/dialog_controller.rb`: `view` resolves to
  `model.active_view` (capability-checked), NOT nonexistent
  `dialog.get_view` (BLOCK-004).
- `core/analysis_result.rb#summary`: exposes the locked Edges /
  Vertices / non-zero-Z vertices / warnings / issues[per-type]
  sub-fields required by the Stage 6 plan (BLOCK-006).
- `compatibility/su_capability.rb#active_edit_context_facts`:
  empty/root active path is the neutral complete state
  (`pid_path_complete: true`); non-empty with any nil slot is fail
  closed. Structural depth = entity count, NOT filtered PID length
  (BLOCK-001, Gate B proof #1+#2).

### Test-side changes
- `tests/_fake_ui.rb` (new): real Module for the UI constant with
  `UI::Command` + `UI::HtmlDialog` constants and per-instance `menu` /
  `HtmlDialog.new` delegation. `FakeUI::State` records menus + dialogs
  per test, with `install!` / `reset!` / `uninstall!` lifecycle so the
  no-UI world is restored after every test.
- `tests/test_loader.rb` (new): 6 FakeUI-based tests proving register!
  is idempotent, keeps the dialog reference, wires to the boot
  entrypoint, and the menu command handler is on_analyze_selection
  (BLOCK-002).
- `tests/test_dialog_runner.rb` (new): 8 lifecycle tests + 3 BLOCK-004
  end-to-end tests proving the menu -> dialog -> locate -> selection
  flow + unresolved toast control + ready handshake (BLOCK-003, 004, 006).
- `tests/test_html_render.rb` (new): 11 HTML/JS contract tests proving
  namespace consistency, no forbidden patterns, no overlay,
  textContent-only render, BLOCK callbacks not method(:) (BLOCK-003, 006).
- `tests/test_analyzers_runner.rb` (new): 3 failing-analyzer injection
  tests proving the per-analyzer recovery contract (BLOCK-005).
- `tests/test_preflight_runner.rb`: 3 BLOCK-001 build_snapshot
  integration tests (root Edge valid PID -> complete, nested
  valid-PID chain -> complete, active path with nil PID -> incomplete)
  per CodeX Round 018 BLOCK-001 minimum acceptable fix (BLOCK-001).
- `tests/test_preflight.rb`: capability probe (positive) ensure-block
  rewritten to be robust against UI already being a non-Module
  (defensive cleanup; the FakeUI was a plain class instance before
  this rework and leaked state).
- `tests/test_ui_bridge.rb`: `summary` keys assertion corrected (per-
  type counts live under `summary['issues']`, not at top level).
- `tests/test_html_render.rb`: file paths corrected from `../../`
  (resolves to D:/Projects/...) to `../` (resolves to the real
  project root); comment-stripping for the `eval` / `new Function`
  regex check; regex updated for `var ROOT = window.SUAIP` style.

### What remains
- CodeX Round 019: BLOCK RECHECK for the 6 closed BLOCKs. We expect
  PASS; if BLOCKs come back, fix in another consolidated pass.
- Owner Verification Stage 6 (real SketchUp 2020) �� `Review/OWNER_VERIFICATION_STAGE_6.txt`
  steps J..N. Owner is the only one who can run this (Q002=A).
- SU2017 minimum-host verification remains a release Gate (per R004);
  not a Stage 6 blocker.
- Packaging / .rbz for SketchUp Extension Manager �� not yet started;
  will follow Owner Verification Stage 6 PASS.

### Hard-rule compliance (per Cicada 2026-08-18 section ��)
- ? Does NOT change R001-R005 product decisions
- ? Does NOT expand product scope (no overlay, no repair, no mutation)
- ? Does NOT push / publish / release
- ? Does NOT skip Owner verification
- ? Does NOT fake SU2017 as SU2020 evidence

## CODEX REVIEW 019 (2026-08-18) �� GATE B RECHECK v2: BLOCK-002-R2 + BLOCK-006-R2 CLOSED

**Verdict**: BLOCK-001, -003, -004, -005, -006 stay CLOSED.
BLOCK-002-R2 (boot path is not executable as documented) and
BLOCK-006-R2 (per-issue-type summary counts not rendered) both
closed in this pass. Full test suite: 247/247 PASS, 0 fail, 0 error.

### Code-side changes (Round 019 rework)
- `extension/su_ai_plugin.rb`:
  - `file_loaded(...)` moved INTO the success branch �� only marked
    on full boot success. A transient boot failure leaves the loaded
    state unset, so the next load retries from scratch (per BLOCK-002-R2
    safe-retry contract).
  - Boot path is now a single method `SUAnalysis::Boot.boot!` that
    `require_relative`'s the deps in safe order and calls
    `Loader.register!` exactly once.
- `extension/html/app.js`:
  - `render(payload)` now emits per-issue-type counters in the locked
    canonical order (7 types: duplicate_edge_candidate, short_edge,
    open_endpoint, gap_candidate, significant_non_zero_z,
    abnormal_large_coord, deep_nesting) with human-readable labels
    ("Short Edges: 1", "Duplicate Candidates: 0", ...). The scalar
    header rows (Edges, Vertices, non-zero-Z, Warnings) come first,
    then the per-issue-type rows �� both linear, no nested-object
    stringification ("[object Object]") anywhere. Exposed
    `ROOT.ISSUE_TYPE_LABELS` for harness introspection.
- `tests/_fake_ui.rb`:
  - `FakeMenu#add_submenu` no longer does nonstandard create-or-return
    semantics. It always creates a NEW submenu �� mirroring the real
    `Sketchup::Menu` API, which does not guarantee find-or-create.
    Production idempotency relies on `file_loaded?` + module-level
    `@registered` sentinel, NOT on this method (per BLOCK-002-R2).

### Test-side changes (Round 019 rework)
- `tests/test_loader.rb` (rewrite):
  - Top-level `file_loaded?` / `file_loaded` / `file_unloaded` stubs
    so the test's `instance_eval` runner sees them via the entrypoint.
  - 1 NEW test "faithful boot �� load entrypoint twice, one menu item,
    handler reaches dialog" that:
    - Actually `load`s `extension/su_ai_plugin.rb` twice.
    - Asserts exactly ONE menu item across both loads.
    - Invokes the created command handler through to the dialog
      boundary (FakeUI.state.dialogs.length == 1).
    - After `file_unloaded` + sentinel reset, asserts the
      honest FakeMenu surfaces a SECOND submenu (proving the
      production code relies on `file_loaded?`, not on FakeMenu
      find-or-create).
  - 1 NEW assertion in "boot entrypoint exists and uses file_loaded?
    guard" that the `file_loaded` call comes AFTER `Boot.boot!` in
    the source.
  - 1 NEW "menu command handler is wired AND clicking it reaches
    the dialog" that actually invokes the handler (not just checks
    the name).
- `tests/test_html_render.rb` (additions):
  - 1 NEW test that spawns Node.js to actually `vm.runInContext`
    `extension/html/app.js` with a mock DOM, call `render(payload)`,
    and inspect the rendered children for the locked labels
    (Short Edges: 1, Duplicate Candidates: 0, etc.) and absence of
    "[object Object]".
  - 1 NEW source-text assertion that the locked `ISSUE_TYPE_LABELS`
    array exists in the canonical order.
- `tests/test_html_render_dom.js` (NEW): the Node.js executable
  render test (17 inline assertions, prints "PASS" on full success).
- `Review/OWNER_VERIFICATION_STAGE_6.txt` (rewritten step J):
  - Removed the 22-line manual file list.
  - Step J.1 now says: `load
    "D:/Projects/SU-AI-Plugin/extension/su_ai_plugin.rb"` (the
    supported entrypoint).
  - Step J.3 IDEMPOTENCY now points to the faithful boot test
    (not UI::Menu introspection) and the real-host path is
    `file_unloaded 'SU-AI-Plugin/extension/su_ai_plugin'` +
    re-load the entrypoint (NOT direct `load loader.rb`).

### NIT fixes (Round 019 NIT)
- This packet uses atx-style `### H2` headings (no `=======`
  underline) so `git diff --check` does not flag a conflict-marker
  pattern in the markdown source. The previous packet had a
  `git diff --check: PASS` claim but the independent command
  actually reported a conflict-marker pattern on the underline
  lines; the claim has been dropped. The packet's diff itself is
  clean.
- The "menu -> dialog" test was renamed to "menu command handler
  is wired AND clicking it reaches the dialog" and now ACTUALLY
  invokes the handler (not just calls `DialogRunner.show`
  directly). Future packet wording matches what executes.

### What remains
- CodeX Round 020: BLOCK RECHECK for the 2 closed BLOCKs. Expected
  PASS.
- Owner Verification Stage 6 (real SketchUp 2020) �� `Review/OWNER_VERIFICATION_STAGE_6.txt`
  steps J..N. Owner is the only one who can run this (Q002=A).
- SU2017 minimum-host verification remains a release Gate (per R004).
- Packaging / .rbz for SketchUp Extension Manager �� not yet started;
  will follow Owner Verification Stage 6 PASS.

### Hard-rule compliance (per Cicada 2026-08-18 section ��)
- ? Does NOT change R001-R005 product decisions
- ? Does NOT expand product scope (no overlay, no repair, no mutation)
- ? Does NOT push / publish / release
- ? Does NOT skip Owner verification
- ? Does NOT fake SU2017 as SU2020 evidence

## CODEX REVIEW 020 (2026-08-18) �� GATE B FINAL: PASS WITH NITS

**Verdict**: PASS WITH NITS. All 6 Gate B BLOCKs + the 2 Round-019
reopens (BLOCK-002-R2, BLOCK-006-R2) are CLOSED. The two NITs are
narrow checklist/evidence-hygiene corrections; no new review is
required.

### NIT corrections applied (CodeX Round 020)
- NIT 1 �� `file_unloaded` is not a documented SketchUp top-level
  API. The real API is `file_loaded?` / `file_loaded` only. Removed
  the Owner instructions that called `file_unloaded`. Step J.3
  now states that idempotency is covered by the automated
  faithful-boot test (no manual Ruby-Console visual confirmation
  is required).
- NIT 2 �� `tests/_fake_instance_path.rb` and
  `tests/test_no_overlay_lint.rb` were referenced in the checklist
  inventory but do not exist in HEAD. Removed the inventory entries
  and the step N.6 "load test_no_overlay_lint" instruction. N.6
  now relies on the existing recursive fingerprint + direct
  real-host property observation.

### Hard-rule compliance (per Cicada 2026-08-18 section ��)
- ? Does NOT change R001-R005 product decisions
- ? Does NOT expand product scope
- ? Does NOT push / publish / release
- ? Does NOT skip Owner verification
- ? Does NOT fake SU2017 as SU2020 evidence

### Next action
**Dispatch Owner Verification Stage 6** �� `Review/OWNER_VERIFICATION_STAGE_6.txt`
J..N on real SketchUp 2020. Owner is the only one who can run
this (Q002=A). Once Owner reports PASS, the next gate is the
SU2017 minimum-host verification (release Gate, per R004; not a
Stage 6 blocker). After that, packaging / .rbz for the SketchUp
Extension Manager.

## REAL-HOST BLOCK (Owner repro 2026-08-18) �� CLOSED

**Verdict**: BLOCK reported by Owner via direct message (not via
CodeX in Prompt/). Root cause: two related gaps.

### Code-side changes
- `extension/preflight_runner.rb`:
  - New public `normalize_selection(input)` that snapshots any
    Selection-like enumerable to a stable Array (to_ary -> each ->
    rescue chain).
  - `build_snapshot` calls `normalize_selection` at the very top,
    so preflight collection + walk iterate the same stable Array.
- `extension/analyzers_runner.rb`:
  - `run(selection, model: nil)` normalizes the selection once at
    the boundary; uses the normalized form for build_snapshot +
    selection_label_for + classification_label.
  - `preflight` is now a real `SUAnalysis::Core::PreflightReport`
    via `PreflightAnalyzer.run(snapshot)` (replaced the previous
    Hash from `collect_preflight_facts`). This makes
    `AnalysisResult#summary` able to read real `edge_count`,
    `vertex_count`, etc.

### Test-side changes
- `tests/test_preflight_runner.rb`: NEW `OneShotEnumerable` mock
  that mirrors a real SU Selection with one-shot iteration
  (responds to `:each` / `:count` / `:first` / `:to_a` / `:length`
  / `:empty?` but clears its items after the FIRST `.each` call).
  5 new tests:
  1. `build_snapshot` with OneShotEnumerable returns 4 edges.
  2. Without normalize, OneShotEnumerable returns 0 edges (proves
     the fix is required).
  3. `normalize_selection` converts Selection-like to a stable
     Array.
  4. `AnalyzersRunner.run` with OneShotEnumerable returns 4 edges.
  5. Array input still works (regression on the fix).

### Lessons
- **Always normalize Enumerable at the API boundary.** Real-world
  Enumerables can have iteration quirks (one-shot, lazy,
  side-effecting). A cheap `Array.dup` at the boundary removes an
  entire class of real-host bugs.
- **`safe_attr` on a Hash always returns the default.** A Hash
  returns `false` for any method-name symbol, so `safe_attr(pf,
  :edge_count, 0)` on a Hash returns 0. The downstream code path
  was designed for a PreflightReport; the Hash was an upstream
  architecture gap that survived because fake-host tests
  happened to pass a Struct, not because the production path was
  correct.
- **The fake-host suite is only as strong as its mocks.**
  `FakeSU::Selection` does NOT have one-shot iteration, so it
  cannot surface this real-host bug. The new `OneShotEnumerable`
  mock explicitly exhibits the one-shot behavior to prove the
  fix and to catch any regression.

### Next action
Owner re-runs the required recheck on real SU 2020:
- Menu Analyze selection on the 4-edge Group must show
  `Edges: 4, Vertices: 4, Warnings: 0`.
- Then rerun Owner K..N per `Review/OWNER_VERIFICATION_STAGE_6.txt`.

## REAL-HOST BLOCK (Owner repro 2026-08-18, RECHECK) — CLOSED

**Verdict**: BLOCK REOPEN from Owner on the same SketchUp 2020 repro.
The previous fix's `to_ary`-first strategy was NOT valid for the real
host: `Sketchup::Selection#to_ary` returns an empty Array on SU2020
even when entities are selected. A second latent bug also surfaced:
`AnalyzersRunner.run` reused the variable name `normalized` for both
the selection array and the issues array, so `classification_label`
saw the (empty) issues array and returned `'empty'`. Both fixed.

### Code-side changes (commit `efe2242`)
- `extension/preflight_runner.rb`:
  - `normalize_selection` no longer trusts `to_ary`. New priority:
    1. `to_a` (documented Sketchup::Selection public API; one-pass
       capture returning a stable Array).
    2. Manual `each` iteration (fallback when `to_a` is missing
       or returns non-Array).
    3. Empty array.
  - On SU2020, `Sketchup::Selection#to_ary` returns [] even when
    entities are selected (Ruby's strict array-coercion idiom),
    so any path treating `to_ary` as authoritative silently empties
    the normalized selection. The fix prefers `to_a` (the documented
    API).
  - `build_snapshot` calls `normalize_selection` at the very top.
- `extension/analyzers_runner.rb`:
  - The selection-boundary variable is renamed to
    `normalized_selection`. The issue-normalization array is renamed
    to `normalized_issues`. The two MUST NOT share a name: with the
    previous single-name `normalized`, the variable was shadowed
    inside the run() body (after `normalized = []` for issues),
    causing `selection_label_for(normalized)` and
    `classification_label(normalized)` at the end of run() to be
    called on the issues array (often empty for a closed rectangle).
  - For the OWNER's repro (4-edge Group): `classification_label`
    now sees the `[group]` array, not `[]`, so
    `result.selection_type == 'selection'` (NOT `'empty'`), and
    `result.selection_label == 'Group: test_group'`.

### Test-side changes
- `tests/test_preflight_runner.rb`: NEW `BrokenToArySelection` mock
  that explicitly mimics the SU2020 bug — `respond_to?(:to_ary)` is
  true, `to_ary` returns `[]`, but `to_a` / `count` / `each` /
  `first` / `length` / `empty?` all correctly report the entities.
  8 new regression tests:
  1. `normalize_selection` with BrokenToArySelection returns
     `[group]` (not `[]`).
  2. `build_snapshot` with BrokenToArySelection returns 4 edges.
  3. `AnalyzersRunner.run` with BrokenToArySelection returns
     `summary['edges'] == 4`, `vertices == 4`, `warnings == 0`.
  4. `selection_type != 'empty'` for BrokenToArySelection.
  5. White-box: `normalize_selection` does NOT call `to_ary`.
  6. Closed-rectangle `selection_type != 'empty'` (variable-shadow
     guard).
  7. `selection_label == 'Group: test_group'` (uses the Group's
     typename + name, not the generic default).
  8. (Existing) OneShotEnumerable tests still pass (5 tests).

### Required Owner recheck (on real SU 2020)
Per the OWNER's required recheck criteria:
1. `selection.add(test_group)` => 1.
2. `AnalyzersRunner.run(model.selection).summary['edges']` => 4.
3. `result.selection_type` must NOT be `"empty"`.
4. Menu dialog must show Edges: 4, Vertices: 4, Warnings: 0.
All four are now covered by automated fake-host tests. The OWNER
should rerun J..N on real SU 2020 to close the loop.

### Lessons
- **Do NOT trust `to_ary` as an authoritative conversion path on
  SketchUp Selection.** SU2020's `Selection#to_ary` returns `[]`
  even when the selection contains entities. The documented public
  API is `to_a`; the `to_ary` is a Ruby-implicit-coercion marker
  that SketchUp honors with the empty-Array idiom.
- **Avoid variable shadow in long methods.** `AnalyzersRunner.run`
  is ~50 lines; reusing the name `normalized` for two semantically
  different arrays (selection vs issues) caused a silent bug
  (`selection_type == 'empty'`) that only surfaced on real host
  with a no-issue selection (closed rectangle). The fix uses
  distinct names: `normalized_selection` and `normalized_issues`.
- **The fake-host suite is only as strong as its mocks.**
  `FakeSU::Selection` does NOT mimic the SU2020 `to_ary` bug, so
  the previous round's tests could not surface it. The new
  `BrokenToArySelection` mock explicitly exhibits the broken
  `to_ary` to prove the fix and to catch any regression.

### Hard-rule compliance (per Cicada 2026-08-18 section 6)
- Does NOT change R001-R005 product decisions.
- Does NOT expand product scope (no overlay, no repair, no mutation).
- Does NOT push / publish / release.
- Does NOT skip Owner verification.
- Does NOT fake SU2017 as SU2020 evidence.

## REAL-HOST BLOCK (Owner K2 repro 2026-08-18) — CLOSED

**Verdict**: K2 Owner-reported BLOCK on fresh SU2020: two coincident
component instances crash Analyze selection with
`NoMethodError: undefined method 'normalize_location' for
SUAnalysis::Core::IssueNormalizer:Module`, called from
`normalize_analyzer_issue` (reached via `extension/analyzers_runner.rb:96`).

### Root cause

`core/issue_normalizer.rb` used `module_function` at the top, then
declared `private` before its helper methods
(`normalize_location`, `sanitize_message`, `normalize_metadata`,
`canonical_preflight_code`, `severity_for_preflight`). In Ruby, the
`private` keyword overrides the `module_function` flag for
subsequent methods — so those helpers became PRIVATE INSTANCE
METHODS only, NOT module singleton methods.

### Why tests masked it

The test files (`tests/test_issue_normalizer.rb`,
`tests/test_issue_enricher.rb`) do
`include SUAnalysis::Core::IssueNormalizer` at the top. The
include adds the module's private instance methods to Object's
ancestor chain, which makes `Module.normalize_location(...)`
succeed via the include chain. So tests passed.

Production code (`extension/analyzers_runner.rb`) does NOT include
IssueNormalizer. So on the production call path, the implicit-self
call to `normalize_location(...)` from inside
`normalize_analyzer_issue` raised `NoMethodError: undefined method
'normalize_location' for SUAnalysis::Core::IssueNormalizer:Module`.

The first issue with a non-nil 3D location dispatched to
`normalize_location(loc)` and crashed the entire Analyze selection
command. On the K2 repro (two coincident component instances), the
duplicate issue has a non-nil `location: [200.0, 0.0, 0.0]`, which
triggers the bug on the first call.

### Code-side changes (commit `1133dcd`)
- `core/issue_normalizer.rb`:
  - Removed the `private` keyword (it broke `module_function` for
    subsequent methods).
  - Defined ALL helpers after `module_function` so they ARE
    module singleton methods (callable from production's
    `SUAnalysis::Core::IssueNormalizer.normalize_analyzer_issue(raw)`
    form AND from inside-the-module implicit-self form).
  - Marked helpers as `private_class_method` at the bottom of the
    module. This preserves the original `private` intent (helpers
    are internal, not part of the public API) WITHOUT breaking
    module-method dispatch.
  - The public API methods (`normalize_analyzer_issue`,
    `normalize_preflight_warning`, `normalize_preflight_warnings`,
    `canonical_severity`, `severity_for_type`) remain PUBLIC
    module singleton methods.

### Test-side changes (10 NEW in `tests/test_issue_normalizer.rb`)
- Production-path tests (no `include` in scope), exercising the
  exact fully-qualified call form used by `analyzers_runner.rb`:
  1. `normalize_analyzer_issue` with non-nil 3D location (the K2
     crash point).
  2. Non-Float location components coerced via `Float()`.
  3. Non-nil metadata Hash round-trips.
  4. Control-character message sanitized.
  5. `normalize_preflight_warnings` with all 3 codes (production
     path for the OTHER public API).
  6. Unknown preflight code returns `[]`.
  7. Helpers are private module methods (visibility contract).
  8. Public API remains public module methods (no public methods
    accidentally marked private).
  9. K2 full repro: duplicate with non-nil location via
     production call form returns the correct issue Hash.
  10. K2 batch repro: 3 mixed raw issues (some with non-nil
      locations) all survive production-path normalization.

### Required Owner recheck (real SU 2020)
- Two coincident component instances.
- Analyze selection must show:
  - **Edges: 2** (each occurrence's Edge in world coords).
  - **Duplicate Candidates: 1** (one Issue row, two SourceTokens).
  - **Warnings: 0** (no preflight warnings).
- No Ruby exception.
- The full pipeline test in the fix commit exercises exactly this
  scenario end-to-end via FakeSU; both Edge count, Duplicate count,
  Warning count, and the "no exception" invariant are covered.

### Lessons
- **`private` after `module_function` overrides `module_function`.**
  In Ruby, `module_function` (no args) sets a flag that affects
  subsequent method definitions until another visibility modifier
  is seen. `private` is such a modifier: methods defined after it
  become PRIVATE INSTANCE METHODS only, not module singleton
  methods. Use `private_class_method` instead to mark a module
  singleton method as private without breaking the module
  singleton method table.
- **`include M` at the top level can mask module-method visibility
  bugs.** The include pulls M's private instance methods into
  Object's ancestor chain, which makes `Module.foo(...)` succeed
  via the include chain — even when `foo` is NOT a module singleton
  method. Tests that rely on `include` to call helper methods will
  not catch this kind of regression; production-path tests that
  use the fully-qualified call form (no include in scope) are
  required.
- **The fake- suite suite is only as strong as its tests.** The
  previous test file's `include SUAnalysis::Core::IssueNormalizer`
  made the bug invisible. The new tests use the production call
  form (no include), exercising the exact dispatch path used by
  `extension/analyzers_runner.rb`.

### Hard-rule compliance (per Cicada 2026-08-18 section 6)
- Does NOT change R001-R005 product decisions.
- Does NOT expand product scope.
- Does NOT push / publish / release.
- Does NOT skip Owner verification.
- Does NOT fake SU2017 as SU2020 evidence.

## L3 non-locatable warning (Owner repro 2026-08-18) — CLOSED

**Verdict**: L3 BLOCK REOPEN from Owner: clicking the Deep Nesting
warning in the dialog shows the toast "source no longer available
for: deep_nesting|1" even though the warning is intentionally
non-locatable (no source token to resolve). SEL=1 and ACTIVE_PATH=0
are unchanged, but the toast makes the row look like a stale
source. The warning must NOT invoke Locate at all.

### Root cause

`extension/html/app.js#renderIssue` unconditionally added a click
listener that called `window.sketchup.locate(id)` for every
issue row. For non-locatable rows (preflight warnings like
`deep_nesting` and `abnormal_large_coord`), the locator
policy (`core/issue_locator_policy.rb#targets_for`) returns `[]`,
the host-side glue returns `:unresolved`, and `dialog_runner.rb`'s
`on_locate` fires the misleading "source no longer available for:
..." toast.

### Code-side changes (commit `4940613`)
- `extension/html/app.js`:
  - `renderIssue` now gates the `addEventListener('click', ...)`
    on `issue.locatable === true`. For `locatable === false`,
    **NO** click listener is registered. There is no path to
    `window.sketchup.locate` and therefore no path to the toast.
  - For `locatable === false`, the row carries a `no-action` CSS
    class and `data-locatable="false"`. The locked render contract
    (textContent + setAttribute, no innerHTML for user strings,
    no eval / no new Function / no document.write) is preserved.
  - For `locatable === true`, behavior is unchanged: the row gets
    a click listener that calls `window.sketchup.locate(id)` and
    does NOT carry the `no-action` class.
- `extension/html/style.css`:
  - New `.issue.no-action` block: `cursor: default` and
    `:hover { background: transparent }` so the row visually
    signals "intentionally not clickable" without hiding the
    warning. The locked severity palette (R005) is unchanged.

### Test-side changes
- `tests/test_html_render_dom.js`:
  - MockElement.addEventListener now records listeners so the L3
    tests can assert WHICH rows have click handlers registered.
  - MockElement exposes `hasListener(name)` for assertion.
  - MockElement exposes className getter/setter that maintains a
    `classes` array (split on whitespace) so tests can assert
    class membership the same way they would with real DOM.
  - 12 NEW ASSERT lines cover:
    - **L3.1** locatable row has click listener registered.
    - **L3.1** locatable row data-locatable attr is "true".
    - **L3.1** locatable row does NOT carry no-action class.
    - **L3.2** non-locatable row has NO click listener.
    - **L3.2** non-locatable row data-locatable attr is "false".
    - **L3.2** non-locatable row carries no-action class.
    - **L3.1** clicking locatable row invokes window.sketchup.locate ONCE.
    - **L3.1** locate receives the issue_id.
    - **L3.2** clicking non-locatable row does NOT invoke locate.
    - **L3.2** clicking non-locatable row N times still does NOT invoke locate.
- `tests/test_html_render.rb`:
  - 3 NEW Ruby-level tests:
    - Source-level guard: `addEventListener('click', ...)` appears
      exactly ONCE in app.js and is gated by `if (locatable)`.
    - Style contract: `.issue.no-action` is defined in style.css
      with `cursor: default` AND a `:hover` override.
    - The Node.js DOM test runs and the L3 ASSERT lines all PASS.

### Owner recheck (real SU 2020)
- Click Deep Nesting warning.
- No selection change, no camera change, no toast, no Ruby error.
- Warning visibly appears non-actionable (default cursor, no hover).
- All four invariants above are now covered by automated tests.

### Lessons
- **JS click handlers should mirror the data-model policy.** The
  locator policy already returns `[]` for non-locatable issues
  (`core/issue_locator_policy.rb#targets_for`). The JS click
  handler should respect the same boundary: do not register a
  handler at all for non-locatable rows. Adding the handler and
  having it return `:unresolved` produces a misleading toast
  ("source no longer available") that confuses the user.
- **Mock DOMs need to track listeners for click-handler tests.**
  The previous MockElement.addEventListener was a no-op, which
  made it impossible to assert which rows had handlers registered.
  For L3 (and any future click-dispatch contract tests), the mock
  must record listeners so tests can probe `hasListener('click')`.
- **CSS class membership is not the same as className string
  equality.** `className` is a space-separated string; testing
  membership requires splitting on whitespace. Mock DOMs should
  expose a `classes` array (and tests should use it) the same way
  real DOM testing libraries do (e.g. `element.classList.contains`).

### Hard-rule compliance (per Cicada 2026-08-18 section 6)
- Does NOT change R001-R005 product decisions.
- Does NOT expand product scope.
- Does NOT push / publish / release.
- Does NOT skip Owner verification.
- Does NOT fake SU2017 as SU2020 evidence.
