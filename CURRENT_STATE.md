# CURRENT STATE

Last updated: 2026-08-17 (Codex Review 004 received: Stage 2 SU adapter
                          BLOCKED with 5 BLOCKS; pure-Ruby 33/33 PASS;
                          R001-R005 all ANSWERED; Stage 2 BLOCK rework
                          queued per CODEX_REVIEW_004 execution order).

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

## Next Step (Phase C — STAGE 2 BLOCK REWORK queued)

1. ✅ **已结束** — Q001-Q004 ANSWERED + 代码兼容性修正 + 文档
2. ✅ **已结束** — 隔离 Ruby 实跑 Stage 1 tests + Stage 1 stable checkpoint
   (commit `5e32ab1`)
3. ✅ **已结束 (pure-Ruby 部分)** — Stage 2 Preflight 纯 Ruby 7/7 PASS
   (commit `6eb33e8`), SU 端后被 Codex 标记 BLOCKED
4. ✅ **已结束** — R001-R005 决策档 + OWNER HANDOFF PROTOCOL 落地
   (commits `c9a3817`, `48bad47`)
5. ✅ **已结束** — Codex Review 004 落地: R001-R005 全部标 ANSWERED,
   CURRENT_STATE 反映 BLOCKED 现状 (本批次 commit)
6. ⏳ **下一步 (本轮可继续)** — Stage 2 BLOCK REWORK — 修 S2-BLOCK-001..005
   + adapter-level stub tests + 重跑 33/33 tests, 见
   `Review/CODEX_REVIEW_004_BLOCK_REWORK_PLAN.md` (本批次 commit)
7. **BLOCK recheck PASS 后** — Owner 跑真 SU 验证 (Q002=A) +
   走 R004 posture B (SU2017 必须)
8. **Stage 6** — UI (per R003 + R005): HtmlDialog + selection/camera Locate
   + grouped issue sections + canonical severity
9. **Stage 7** — TASK 001 IMPLEMENTATION REPORT (PI_TASK_001 §22)
10. **最终 Gate 前** — Ruby 2.2.4 / SU2017 真机证据 (R004 posture B)


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
