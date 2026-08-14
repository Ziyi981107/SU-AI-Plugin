# CURRENT STATE

Last updated: 这一轮 (Stage 0 + Stage 1 落地,见 AGENT.md §18)

## 已完成

### Stage 0 — 仓库骨架
- `git init -b main`(本地仓库,不 push)
- `.gitignore`(SU/CAD/编辑器/OS/Ruby 临时)
- `README.md`(项目入口 + 文件地图 + 假设标注表)
- 自建 `tests/runner.rb` + `tests/run_all.rb`(零 gem 依赖)
- 占位目录 `analysis/ issues/ ui/ extension/ compatibility/ config/` 留空待后续阶段填充

### Stage 1 — 纯 Ruby Geometry Core + Synthetic Test Set
- 数据模型: `Tolerance / SourceReference / EdgeRecord / VertexRecord / LayerRecord / AnalysisConfig / GeometrySnapshot`
- 空间桶: `QuantizeKey / VertexIndex`
- 4 个 Analyzer: `DuplicateDetector / ShortEdgeDetector / OpenEndpointDetector / GapCandidateDetector`
- 测试构造器: `SyntheticFactory`
- Synthetic Tests TC-01..TC-10 + issue 字段完整性测试 + tolerance 边界测试
- 代码风格: Ruby 2.2+ safe(无 pattern matching / numbered params / endless method / kwargs 分离糖),覆盖 SketchUp 2017+ 全段
- **.gitignore 接受 SketchUp 临时 / CAD 临时 / rbz 产出**

### Stage 1 自测
- ❗ **未在 Agent 环境跑通**:Agent 环境没有 Ruby。下载 RubyInstaller (150MB) 5 分钟超时,按 AGENT.md §3 "external irreversible action is unsafe" 转 Review 升级。
- 代码已 writing 完成,只需要在任何 Ruby 2.4+ 环境(含 SketchUp 主机)运行 `ruby tests/run_all.rb`。
- 7 天内代码会被 Codex / Product Owner 自检。

## 进行中

无(Stage 1 代码已落盘,等待测试执行结果)。

## 等待中

| ID | 内容 | 路径 |
|---|---|---|
| Q001 | git workflow 决策 | Review/Q001_git_workflow.txt |
| Q002 | real SketchUp 验证责任 | Review/Q002_real_sketchup_verification.txt |
| Q003 | target SU version 基线 | Review/Q003_target_sketchup_version.txt |
| **Q004** | **Agent 环境是否装 Ruby** | **Review/Q004_ruby_in_agent_env.txt** |

## 当前假设 (Q001-Q003)

| 项 | 假设 | 落地形式 |
|---|---|---|
| Q001 | B (本地 git init,不 push,阶段 commit) | 已 git init 并设 config;每 stage 一 commit |
| Q002 | A (Owner 在 SketchUp 环境实测,Agent 不自验) | IMPLEMENTATION REPORT §6 将明确"pending external verification in real SU" |
| Q003 | B (SU2018+ 基线,SU2017 走 fallback adapter) | 代码使用 Ruby 2.2+ safe 语法;`SourceReference#stable?` 已为 fallback 留接口 |

代码注释与 README 已明示这些假设。若 Codex 实际答案不同,Stage 7 IMPLEMENTATION REPORT 会记录并列出受影响的代码位置。

## 已知问题 / Lessons

- **Lessons (Agent 环境)** :试图装全局 RubyInstaller 来跑 synthetic tests 是错误方向。正确做法是交付代码 + 让你在 Ruby 环境跑。这条经验是 generic 经验,值得 promote 到 AGENT.md (经 Codex / AIPM 审)。
- **代码** :无已知 block。Synthetic tests 全部独立于 SU,失败立刻可见。

## Next Step (按依赖顺序)

1. (等待 Product Owner / Codex) Q001-Q003 + Q004 反馈落到 `Prompt/`。
2. (不需要等待就能立即做) 在你跑 `ruby tests/run_all.rb` 后把输出写进 `Prompt/`,Agent 据此进入 Stage 2 (Preflight)。
3. (若你确认 Q003=B) 进入 Stage 5 (SketchUp Integration Layer) — 写真 `extension/` 与 `compatibility/` 代码。
4. (若你确认 Q002=A) 给出 `extension/` 的安装说明和 UI 截图要求,你真实开 SketchUp 走一遍主流程。
5. Stage 7 = TASK 001 IMPLEMENTATION REPORT(按 PI_TASK_001 §22 格式)。
