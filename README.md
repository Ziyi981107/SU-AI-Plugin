# SU-AI-Plugin

> SketchUp 建筑方案自动化插件
> 当前阶段: **V1.0 Read-only CAD Analyzer** (PI_TASK_001)

## 硬约束

* **NEVER MODIFY SOURCE CAD** — 详见 PI_TASK_001 §4
* 所有 tolerance / 阈值集中在 `core/tolerance.rb` + `core/analysis_config.rb`
* `core/` 与 `tests/` 是**纯 Ruby**(零 SketchUp 依赖),可在任何 Ruby 2.4+ 环境跑

## 跑测试

依赖: Ruby 2.2.4+ (兼容 SU2017 内置 Ruby; 推荐 2.2.x 做最低基线验证, 也可用 2.7+ / 3.x; 见 Review/Q003)

```sh
ruby tests/run_all.rb                  # 全部
ruby tests/run_all.rb TC-06            # 单个测试 (按 name 包含匹配)
```

无外部 gem 依赖;仓库内一个 ~80 行的自建 runner。

## 仓库地图

```
AGENT.md              Coding Agent Playbook (Agent 工作手册)
Prompt/               PI 任务文档 + 你写给 Agent 的反馈
Review/               Agent 写给 Codex 的外部决策 (Q001..Q00N + WORKFLOW_PROTOCOL)
core/                 纯 Ruby 几何核心 (本阶段主交付)
  tolerance.rb             集中容差
  source_reference.rb      SU 实体轻量引用
  edge_record.rb           EdgeRecord 数据
  vertex_record.rb         VertexRecord 数据
  layer_record.rb          LayerRecord 数据
  quantize_key.rb          空间 hash 桶
  vertex_index.rb          端点合并 / 开闭判定
  analysis_config.rb       配置容器
  geometry_snapshot.rb     快照聚合 + Preflight 数据
  synthetic_factory.rb     测试 fixture 构造器
  analyzers/
    duplicate_detector.rb      ISSUE 001
    short_edge_detector.rb     ISSUE 002
    open_endpoint_detector.rb  ISSUE 003a
    gap_candidate_detector.rb  ISSUE 003b
analysis/             (Stage 2+) 真 SketchUp 实体扫描与 Preflight 实施
issues/               (Stage 4+) Issue Registry 数据结构
ui/                   (Stage 6+) HtmlDialog / Selection 高亮
extension/            (Stage 5+) SketchUp loader / 菜单 / .rbz 入口
compatibility/        (Stage 5+) SU 版本探测与 adapter
config/               (Stage 4+) Profile 接管 tolerance
tests/                Synthetic Test Set (PI_TASK_001 §16 Test 01..10)
```

## 与 Review/ 的关系 (Q001-Q004 已全部 ANSWERED by Codex)

| 项 | Decision | 实施位置 |
|---|---|---|
| Q001 (git workflow) | **B** — 本地 git init,不 push,每阶段 commit | Stage 0 已落地 |
| Q002 (real SU verification) | **A** — Product Owner 在真 SU 环境实测 | Stage 7 交付前清单 |
| Q003 (target SU version) | **A** — **SU2017+ 硬最低**, Ruby 2.2.4 基线, capability detection | README + CURRENT_STATE 已修正 |
| Q004 (Ruby in Agent env) | **C** — 隔离运行时,真实跑测试,长超时 | `.vendor/` 已在 .gitignore |

所有假设已落地为实际实现 / 文档,不再有未答 OPEN 问题。
