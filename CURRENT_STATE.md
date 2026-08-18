# CURRENT STATE

Last updated: 2026-08-18 (CodeX Round 020 Gate B FINAL recheck:
                          **PASS WITH NITS** — all 6 Gate B BLOCKs +
                          the 2 Round-019 reopens are CLOSED; both
                          NITs are narrow checklist/evidence-hygiene
                          corrections applied. Full suite 247/247
                          PASS, 0 fail, 0 error; git diff --check
                          clean. READY to dispatch Owner Verification
                          Stage 6 (J..N on real SketchUp 2020).)

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
