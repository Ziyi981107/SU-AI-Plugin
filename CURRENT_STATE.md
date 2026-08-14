# CURRENT STATE

Last updated: Codex guidance landed 2026-08-14 (Q001..Q004 ANSWERED).

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

### Stage 1 — 纯 Ruby Geometry Core (代码已就位)
- 数据模型: `Tolerance / SourceReference / EdgeRecord / VertexRecord /
  LayerRecord / AnalysisConfig / GeometrySnapshot`
- 空间索引: `QuantizeKey / VertexIndex`
- 4 个 Analyzer: `DuplicateDetector / ShortEdgeDetector /
  OpenEndpointDetector / GapCandidateDetector`
- `SyntheticFactory` 测试 fixture 构造器
- Synthetic Tests TC-01..TC-10 + 数据模型 + 容差边界 + issue 字段
  完整性测试, 总共 ~25 个 `test` cases
- 代码风格: Ruby 2.2.4-safe (无 pattern matching / numbered params /
  endless method / kwargs 糖 / frozen_string_literal magic)

## Stage 1 自测状态 (Q004=C)

- ❗ Agent 环境之前未跑过 tests (无 Ruby; 之前尝试装系统级 Ruby
  timeout 被否决)
- ⏳ **下一步**: 隔离下载 Ruby (下载到 `.vendor/ruby/` 或系统临时目录),
  不改 PATH, 不入 git, 实际执行 `tests/run_all.rb`,
  保存 PASS / FAIL / ERROR 摘要
- 若 FAIL → 修 → 重跑 → 仍 FAIL 上报
- 若 PASS → 把 Stage 1 commit (9134653) 升格为 stable checkpoint
- `9134653` 当前是 checkpoint 不是 PASS 结果

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

## Next Step (Phase A 已完成 — 现在执行)

1. ✅ **已结束** — Q001-Q004 ANSWERED + 代码兼容性修正 + 文档
2. ⏳ **现在执行** — 隔离下载 Ruby → 实际跑 `tests/run_all.rb` →
   修 FAIL → 重跑 → 报告
3. **通过后** — Stage 1 升格为 stable checkpoint,
   进入 Stage 2 (Preflight: 真 SketchUp 实体选取 / 嵌套扫描 / bbox / Z)
4. **Stage 5** — `compatibility/su_version_probe.rb`,
   capability detection for `persistent_id` etc.
5. **Stage 6** — UI: HtmlDialog (SU2017+ 有)
   + Selection 高亮 (临时 visualizer, 不持久改 material)
6. **Stage 7** — TASK 001 IMPLEMENTATION REPORT (PI_TASK_001 §22 格式),
   并交付 Owner 手动验证清单 (per Q002=A)
