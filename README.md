# Gavin AI Toolkit

个人 AI 能力资产库 —— Skills / Rules / Agents / Templates

用于 CodeBuddy、Claude Code 等 AI 协作工具，实现 SLAM/VIO 代码解读等标准化工作流的快速复用。

## 快速开始

### 选择部署脚本

| 操作系统 | 脚本 |
|---------|------|
| Windows | `deploy.bat` |
| Linux / macOS | `deploy.sh` （需 `chmod +x deploy.sh`） |

### 部署命令格式

```bash
# 通用格式
<deploy_script> <platform> <scope> [project_path]

# platform: codebuddy | claude
# scope:   user | project
```

### 部署示例

**CodeBuddy（推荐）**:

```bash
# Windows
deploy.bat codebuddy user                          # 用户级（全局）
deploy.bat codebuddy project D:\my-slam-project     # 项目级

# Linux / macOS
./deploy.sh codebuddy user                          # 用户级（全局）
./deploy.sh codebuddy project /home/user/my-project # 项目级
```

**Claude Code**:

```bash
# Windows
deploy.bat claude user                              # 用户级（全局）
deploy.bat claude project D:\my-slam-project        # 项目级

# Linux / macOS
./deploy.sh claude user                             # 用户级（全局）
./deploy.sh claude project /home/user/my-project    # 项目级
```

### 目标位置对照表

| Platform | Scope | 目标路径 |
|----------|-------|---------|
| CodeBuddy | User | `~/.workbuddy/skills/{skill_name}/` |
| CodeBuddy | Project | `{project}/.workbuddy/skills/{skill_name}/` |
| Claude Code | User | `~/.claude/commands/` (flat .md files) |
| Claude Code | Project | `{project}/.claude/commands/` |

部署脚本自动遍历 `skills/` 下所有 skill 进行部署。

### 验证部署成功

**CodeBuddy 中输入：**
```
分析 D:/your-slam-project
```

**Claude Code 中输入：**
```
/slam-code-reader D:/your-slam-project
```

---

## 当前包含的 Skill

### slam-code-reader — SLAM/VIO 代码解读工具集

**适用范围**: 任何 SLAM、VIO、视觉惯性导航、传感器融合相关的 C++/Python 代码库

**七步法工作流**:

| Phase | 名称 | 产出 | 可独立执行 |
|-------|------|------|-----------|
| 0 | 资料收集 | 论文 PDF + 文档 + `00_资料清单.md` | ✅ |
| 1 | 代码拓扑扫描 | `01_拓扑结构分析.md` | ✅ |
| 2 | 数据流追踪 | `02_数据流追踪.md` | ✅ |
| 3 | 模块优先级标注 | `03_模块优先级清单.md` | ✅ |
| 4 | 核心模块深度分析 | `04/{module}-deep-dive.md` (每模块一份) | ✅ |
| 5 | 参数清单提取 | `05_参数清单.md` | ✅ |
| 6 | 阅读路线图 | `06_阅读路线图.md` (最终交付物) | ✅ |

**使用方式**:

| 你说的话 / 命令 | 执行内容 |
|-----------------|---------|
| "分析 D:/xxx-project" | 全量执行 Phase 0-6 |
| "收集资料" | 仅 Phase 0 |
| "看一下拓扑结构" | 仅 Phase 1 |
| "追踪数据流" | 仅 Phase 2 |
| "标注优先级" | 仅 Phase 3 |
| "精读 XX 模块" | 仅 Phase 4 |
| "提取参数" | 仅 Phase 5 |
| "生成路线图" | 仅 Phase 6 |

**输出位置**: `{项目根目录}/{仓库名}-code-analysis/`

**详细说明**: 见 [skills/slam-code-reader/SKILL.md](skills/slam-code-reader/SKILL.md)

---

### slam-project-profiler — 项目画像生成工具

**适用范围**: 任何 SLAM/VIO 项目。生成结构化的项目规格文件（`project-spec.md`），供其他 skill 读取使用。

**定位**: 基础设施 skill——其他 skill（debug-helper、eval-runner、log-analyzer 等）执行前都需要读取 spec 文件。

**四步法工作流**:

| Phase | 名称 | 说明 | 可独立执行 |
|-------|------|------|-----------|
| 0 | 自动扫描 | 扫描项目目录、配置、README、代码结构，形成初步假设 | ✅ |
| 1 | 交互确认 | AI 逐项提出假设，用户确认/纠正/补充 | ✅（需 Phase 0） |
| 2 | 生成规格 | 汇总确认信息，生成 `project-spec.md` | ✅（需 Phase 0+1） |
| 3 | 验证 | 用 spec 中的信息尝试读取样本数据，确认可解析性 | ✅（需 Phase 2） |

**使用方式**:

| 你说的话 / 命令 | 执行内容 |
|-----------------|---------|
| "了解这个项目" / "profiler" | 全量执行 Phase 0-3 |
| "扫描项目结构" | 仅 Phase 0 |
| "确认项目信息" | 仅 Phase 1 |
| "更新项目规格" | 更新已有 spec 的指定章节 |

**输出位置**: `{项目}/.specs/project-spec.md`

**详细说明**: 见 [skills/slam-project-profiler/SKILL.md](skills/slam-project-profiler/SKILL.md)

---

### slam-eval-runner — 轨迹评估工具

**适用范围**: 任何 SLAM/VIO 项目。按照用户定义的评估方式运行评估，生成误差时序分析，标注异常区间。

**定位**: 基础能力 skill——为 debug-helper、log-analyzer、perf-optimizer 提供量化评估能力。不自创指标，完全按用户定义的评估脚本工作。

**三步法工作流**:

| Phase | 名称 | 说明 | 可独立执行 |
|-------|------|------|-----------|
| 0 | 读取配置 | 从 spec 中读取评估脚本、轨迹、真值等信息 | ✅ |
| 1 | 运行评估 | 执行用户评估脚本，收集输出 | ✅（需 Phase 0） |
| 2 | 时序分析 | 生成误差时序曲线，标注异常区间 | ✅（需评估数据） |
| 3 | 生成报告 | 汇总评估结果，对比历史 | ✅（需 Phase 2） |

**使用方式**:

| 你说的话 / 命令 | 执行内容 |
|-----------------|---------|
| "跑一下评估" / "eval" | 全量执行 Phase 0-3 |
| "评估 /path/to/traj.csv" | 用指定轨迹文件评估 |
| "分析误差时序" | 仅 Phase 2 |

**输出位置**: `{项目}/.specs/eval-results/{timestamp}/`

**详细说明**: 见 [skills/slam-eval-runner/SKILL.md](skills/slam-eval-runner/SKILL.md)

---

### Skill 组合使用

| 用户指令 | 触发的 skill 链 |
|---------|----------------|
| "帮我了解这个项目" | project-profiler → 生成 spec |
| "分析这段代码" | code-reader |
| "跑一下评估" | eval-runner（读取 spec） |
| "系统发散了" | debug-helper（读取 spec 后排查） |
| 后续更多 skill 开发中... | |

---

## 目录结构

```
gavin-ai-toolkit/
├── README.md                          ← 本文件
├── CLAUDE.md                          ← Claude Code 使用指南
├── .gitignore
├── deploy.bat                         ← Windows 部署脚本
├── deploy.sh                          ← Linux/macOS 部署脚本
│
├── skills/                            ═══ Skills（可执行工作流）═══
│   ├── slam-code-reader/              ← SLAM 代码解读工具集
│   │   ├── SKILL.md                   ← 入口：触发词 + Phase 编排
│   │   ├── phases/                    ← 7 个 Phase 的指令文件
│   │   │   ├── phase0-collect.md
│   │   │   ├── phase1-topology.md
│   │   │   ├── phase2-dataflow.md
│   │   │   ├── phase3-priority.md
│   │   │   ├── phase4-deep-dive.md
│   │   │   ├── phase5-params.md
│   │   │   └── phase6-roadmap.md
│   │   └── templates/                 ← 输出文档模板 (7 个)
│   │       ├── resource-list-template.md
│   │       ├── topology-report-template.md
│   │       ├── dataflow-report-template.md
│   │       ├── priority-list-template.md
│   │       ├── deep-dive-template.md      ← 核心模板: 7-section 精读文档
│   │       ├── param-list-template.md
│   │       └── roadmap-template.md
│   │
│   └── slam-project-profiler/         ← 项目画像生成工具
│       ├── SKILL.md                   ← 入口：触发词 + Phase 编排
│       ├── phases/                    ← 4 个 Phase 的指令文件
│       │   ├── phase0-scan.md
│       │   ├── phase1-understand.md
│       │   ├── phase2-generate.md
│       │   └── phase3-verify.md
│       └── templates/
│           └── project-spec-template.md  ← project-spec.md 输出模板
│
│   └── slam-eval-runner/              ← 轨迹评估工具
│       ├── SKILL.md                   ← 入口：触发词 + Phase 编排
│       ├── phases/                    ← 4 个 Phase 的指令文件
│       │   ├── phase0-spec.md
│       │   ├── phase1-run.md
│       │   ├── phase2-timeseries.md
│       │   └── phase3-report.md
│       └── templates/
│           └── eval-report-template.md   ← 评估报告输出模板
│
├── rules/                             ═══ Rules / System Prompts ═══
│   ├── slam-domain-knowledge.md        ← SLAM 领域知识库
│   └── code-review-checklist.md        ← 代码审查检查清单
│
├── agents/                            ═══ Agent 角色定义 ═══
│   ├── slam-reviewer.md                ← SLAM 代码审查员
│   └── paper-analyst.md                ← 论文分析专家
│
├── references/                        ═══ 参考资料 ═══
│   ├── framework-comparison.md         ← 主流框架特征对照表
│   ├── formula-cheatsheet.md           ← 常用公式速查
│   └── code-patterns.md                ← SLAM 代码常见模式识别
│
└── archives/                          ═══ 历史产出归档 ═══
    └── (按项目存放分析报告)
```

---

## 扩展指南

### 新增一个 Skill

1. 在 `skills/` 下创建新目录:
   ```bash
   mkdir skills/my-new-skill
   ```
2. 编写 `SKILL.md`（参考现有格式）
3. 如需子模块，创建 `phases/` 和 `templates/`
4. 更新本 README 的"当前包含的 Skill"章节
5. 重新运行部署脚本

### 新增一条 Rule

1. 在 `rules/` 下新建 `.md` 文件
2. Rule 可被 Skill 引用或手动注入对话上下文
3. 用于存储领域知识、检查清单、编码规范等非执行性内容

### 新增一个 Agent

1. 在 `agents/` 下新建 `.md` 文件
2. 定义角色名称、专业领域、行为规范
3. 使用时通过 "以 XX 角色身份 review 这段代码" 触发

### 归档历史产出

每次完成一个项目的完整分析后，可将 `{仓库名}-code-analysis/` 目录复制或链接到 `archives/` 下：

```bash
cp -r /path/to/project/vins-mono-code-analysis archives/vins-mono-analysis/
```

---

## License

MIT License — 个人使用，可自由修改和分发。
