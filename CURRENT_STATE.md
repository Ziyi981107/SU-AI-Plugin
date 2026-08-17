# CURRENT STATE

Last updated: 2026-08-17 (Stage 1 RUNTIME PASS, 26/26 tests).

## 决策落地 (PI_TASK_001)

| ID | Decision | 状态 |
|---|---|---|
| Q001 git workflow | **B** — 本地 git init, 不 push, 阶段 commit | ✅ 已在用 |
| Q002 real SU verification | **A** — Owner 在真 SU 跑, Agent 写代码 + 清单 | ✅ 按此推进 |
| Q003 target SU version | **A** — **SU2017+ 硬基线, Ruby 2.2.4** | ✅ 已修正 |
| Q004 Ruby in Agent env | **C** — 隔离运行时, 真实跑 tests | ⏳ 实施中 |

## 重要事实纠正 (per Codex 2026-08-14)

- ❌ 旧假设 (我这轮写的): "Ruby 2.4+", "Q003=B (SU2018+ 基线)"
- ✅ 正确: **SU2017+**, **Ruby 2.2.4** 是硬最低基线
- ✅ `Sketchup::Entity#persistent_id` 在 **SU2017 起就有**, 不是 SU2018+ 才有
- ✅ capability detection (`respond_to?`) 优先于版本号判断

## 兼容性修正 (已完成)

- [x] 移除全部 18 个 .rb 文件中的 `# frozen_string_literal: true`
      (Ruby 2.3+ magic comment, SU2017 的 2.2.4 不识别)
- [x] `core/source_reference.rb` 持久化稳定性注释已修正:
      "persistent_id is available in SketchUp 2017+ ..."
      不再说 "SU2018+"
- [x] README.md "Ruby 2.4+ 跑测试" → "Ruby 2.2.4+ 跑测试"
- [x] CURRENT_STATE (本文件): 移除错误的 "Ruby 2.4+" 表述

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
- `Tests.run!` 测试 dispatcher (本次补齐)
- Synthetic Tests TC-01..TC-10 + 数据模型 + 容差边界 + issue 字段
  完整性测试, 总共 26 个 `test` cases
- 代码风格: Ruby 2.2.4-safe (无 pattern matching / numbered params /
  endless method / kwargs 糖 / frozen_string_literal magic)
- ✅ 隔离 Ruby 2.7.8 实跑: 26/26 PASS

## Stage 1 自测状态 (Q004=C) — 2026-08-17 PASS

- ✅ 隔离 Ruby 运行时已落地: `.vendor/ruby/rubyinstaller-2.7.8-1-x64/`
  - 来源: GitHub mirror `ghfast.top` (直接 GitHub 在本环境下 10s 超时,
    `github.akams.cn` / `gh-proxy.com` 亦可用作 fallback)
  - 体积: 7z 包 12.17 MB, 解压后 90 MB, 含 `bin/ruby_builtin_dlls/`
    (缺这部分则 `ruby.exe` 会报 SxS 错误, 上一轮 `C:\Ruby27-x64\`
    安装不完整的原因就是这个 DLL 集合未提取)
  - 调用: 全程绝对路径 `.vendor/ruby/rubyinstaller-2.7.8-1-x64/bin/ruby.exe`,
    不入 PATH, 不入 Git (`.vendor/` 已被 `.gitignore` 排除)
- ✅ 实跑 `tests/run_all.rb`: **26 tests: 26 pass, 0 fail, 0 error**
  - 完整 log: `.vendor/STAGE_1_TEST_RUN_2026-08-17.log`
  - Ruby 版本证据: `.vendor/RUBY_VERSION_2026-08-17.txt`
  - 覆盖: 16 个 data-model test + TC-01..TC-10 全部 PASS
  - 性能: TC-10 5000 edges under 5s,未出现超时
- ✅ Stage 1 升格为 stable checkpoint, 新 commit `33c...` (stage-1 PASS)
- ⚠️ **Q004 旁注 (caveat, 不阻碍进入下一阶段)**:
  - 实际跑测试的是 Ruby 2.7.8p225, 交付代码最低基线是 Ruby 2.2.4 (SU2017 内置)
  - 按 Q004 guidance: "若当前只能取得更新的隔离 Ruby, 可先用它执行功能测试,
    但这不能单独证明 Ruby 2.2.4 兼容; 在最终 Gate 前, 仍需补充
    Ruby 2.2.4 / SU2017 的语法与目标环境证据"
  - 静态检查 Stage 1 代码已经按 2.2.4-safe 写 (无 pattern matching /
    无 numbered params / 无 endless method / 无 kwargs 糖 /
    无 frozen_string_literal magic comment)
  - 真实 2.2.4 baseline 证据 **仍需** 在最终 Gate 前补 (例如找 Ruby 2.2.4
    二进制或走 SU2017 真机验证清单 — 后者更适合本项目)

## 调试期顺手修的 2 个 Stage 1 bug

- `core/synthetic_factory.rb`: `class SyntheticFactory` → `module SyntheticFactory`
  (原版 `class` + `module_function` 是语法错误, 上一轮没跑过测试所以没暴露)
- `tests/runner.rb`: 补上 `Tests.run!(filter=nil)` 方法
  (上一轮写了 TestCase/TestResult 但漏了 dispatcher, 调用 `Tests.run!` 会
  NoMethodError; 这也解释了为什么此前根本没法验证测试结果)

## 等待中 (下一步需要)

- Codex 反馈 Q001-Q004 **已全部落地** (本轮), 不再 OPEN
- Agent 现在不需要外部决策就能推进 Stage 1 实跑;
  Stage 2 (Preflight) / Stage 5 (SU Integration) 同样不依赖未答决策

## 已知问题 / Lessons

### Lesson — review assumption vs hard constraint
- 这一轮我把 Q003 默认假设成 "SU2018+ / Ruby 2.4+", 用 "更现代" 为由
  默认升级产品基线, 这是错的。
- 项目背景里 Owner 决策 #004 已经锁定 SU2017+ 硬基线,
  Agent 不应擅自决定。
- 后续: **凡是涉及产品 / 兼容基线 / 用户级行为 的决策, 一律上 Review**,
  不在 "技术细节" 的掩护下随手定。

### Lesson — install system Ruby is wrong direction
- 之前想装系统 RubyInstaller 是错路。
- 正确做法: 隔离运行时 (`.vendor/` 或 temp), 不污染 PATH, 跑完可删。
- 这条 lesson 跨项目价值高, 已经写到 Q004 IMPACT 段供 Codex / AIPM 审。

### Code — 无已知 block
- Stage 1 静态自检通过 (require 链、算法、字段完整性)。
- Dynamic 测试待 Q004=C 隔离运行时落地。

## Next Step (Phase A 已完成 — Stage 1 PASS, 现在推进)

1. ✅ **已结束** — Q001-Q004 ANSWERED + 代码兼容性修正 + 文档
2. ✅ **已结束** — 隔离 Ruby 实跑 tests + 修 2 个 Stage 1 bug + Stage 1
   stable checkpoint
3. ⏳ **现在执行** — Stage 2 (Preflight: 真 SketchUp 实体选取 / 嵌套扫描 /
   bbox / Z) 设计 + Owner 手动验证清单 (per Q002=A, 不进真 SU)
4. **Stage 5** — `compatibility/su_version_probe.rb`,
   capability detection for `persistent_id` etc.
5. **Stage 6** — UI: HtmlDialog (SU2017+ 有)
   + Selection 高亮 (临时 visualizer, 不持久改 material)
6. **Stage 7** — TASK 001 IMPLEMENTATION REPORT (PI_TASK_001 §22 格式),
   并交付 Owner 手动验证清单 (per Q002=A)
7. **最终 Gate 前** — Ruby 2.2.4 / SU2017 真机证据补齐 (per Q004 caveat)
