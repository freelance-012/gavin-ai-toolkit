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

### slam-debug-helper — SLAM 系统故障诊断工具

**适用范围**: 任何 SLAM/VIO 项目。从症状出发，通过决策树定位根因，给出可操作的修复方案。

**定位**: 诊断 skill——当 SLAM 系统出现问题时，帮助用户从现象到根因到修复。

**四步法工作流**:

| Phase | 名称 | 说明 | 可独立执行 |
|-------|------|------|-----------|
| 0 | 症状分类 | 确定故障类型（漂移/发散/丢失/初始化失败/回环失败） | ✅ |
| 1 | 信息收集 | 读取 spec + eval 结果 + 日志 + 参数配置 | ✅（需 Phase 0） |
| 2 | 根因诊断 | 按故障类型的决策树逐层排查 | ✅（需 Phase 1） |
| 3 | 修复方案 | 给出可操作的修复步骤 + 验证方法 | ✅（需 Phase 2） |

**使用方式**:

| 你说的话 / 命令 | 执行内容 |
|-----------------|---------|
| "系统发散了" / "debug" | 全量执行 Phase 0-3 |
| "轨迹漂移，帮我看看原因" | 跳过 Phase 0，直接 Phase 1-3 |
| "我已经收集了日志，帮我分析根因" | 跳过 Phase 0-1，直接 Phase 2-3 |

**输出位置**: `{项目}/.specs/debug/{timestamp}/`

**支持框架**: VINS-Mono/Fusion（更多框架持续添加中）

**详细说明**: 见 [skills/slam-debug-helper/SKILL.md](skills/slam-debug-helper/SKILL.md)

---

### slam-log-analyzer — SLAM 日志分析工具

**适用范围**: 任何 SLAM/VIO 项目。解析系统日志，建立日志与代码的映射，分析异常时间段，辅助添加调试日志。

**定位**: 日志分析 skill——当需要深入理解系统运行时行为时，通过分析日志定位问题。

**五步法工作流**:

| Phase | 名称 | 说明 | 可独立执行 |
|-------|------|------|-----------|
| 0 | 日志扫描 | 扫描项目中的日志文件，识别日志格式 | ✅ |
| 1 | 日志解析 | 解析日志，建立时间索引 | ✅（需 Phase 0） |
| 2 | 代码映射 | 建立日志消息与源代码的映射关系 | ✅（需 Phase 1） |
| 3 | 时段分析 | 分析指定时间段内的日志 | ✅（需 Phase 2） |
| 4 | 插桩设计 | 设计并添加调试日志（可选） | ✅（需 Phase 2） |

**使用方式**:

| 你说的话 / 命令 | 执行内容 |
|-----------------|---------|
| "分析日志" / "log" | 全量执行 Phase 0-3 |
| "分析 10-20 秒的日志" | Phase 0-2，然后 Phase 3 分析指定时间段 |
| "帮我加一些调试日志" / "插桩" | Phase 0-2，然后 Phase 4 设计插桩 |
| "分析误差突增时的日志" | 联合 eval-runner，分析异常时间段 |

**输出位置**: `{项目}/.specs/log-analysis/{timestamp}/`

**支持的日志格式**: ROS 日志、自定义格式、纯文本格式

**详细说明**: 见 [skills/slam-log-analyzer/SKILL.md](skills/slam-log-analyzer/SKILL.md)

---

### slam-perf-optimizer — 性能优化编排器

**适用范围**: 任何 SLAM/VIO 项目。自动化"构建 → 运行 → 评估 → 分析 → 诊断 → 修复 → 再运行"的迭代优化循环。

**定位**: 编排 skill——不直接执行评估、分析、诊断，而是编排其他 skill 协同工作，实现性能优化的自动化闭环。

**五步法工作流**:

| Phase | 名称 | 说明 | 可独立执行 |
|-------|------|------|-----------|
| 0 | 初始化 | 读取配置，检查依赖，初始化优化会话 | ✅ |
| 1 | 自动构建 | 编译项目，捕获构建错误 | ✅（需 Phase 0） |
| 2 | 自动运行 | 运行 SLAM 系统，监控进程状态 | ✅（需 Phase 1） |
| 3 | 迭代优化 | 评估 → 分析 → 诊断 → 修复 → 回到 Phase 1 | ✅（需 Phase 2） |
| 4 | 收敛判断 | 检查是否达到目标，生成优化报告 | ✅（需 Phase 3） |

**使用方式**:

| 你说的话 / 命令 | 执行内容 |
|-----------------|---------|
| "自动优化" / "性能优化" | 全量执行 Phase 0-4，自动迭代优化 |
| "跑一轮优化" | 执行一次完整的评估-分析-诊断-修复循环 |
| "从上次结果继续优化" | 读取已有迭代日志，继续优化 |

**输出位置**: `{项目}/.specs/optimization/{timestamp}/`

**核心价值**:
- 自动化编译运行，消除人工干预断点
- 迭代优化循环，持续改进系统性能
- 收敛判断，避免无效迭代
- 完整优化日志，可追溯每次改动

**详细说明**: 见 [skills/slam-perf-optimizer/SKILL.md](skills/slam-perf-optimizer/SKILL.md)

---

### Skill 组合使用

| 用户指令 | 触发的 skill 链 |
|---------|----------------|
| "帮我了解这个项目" | project-profiler → 生成 spec |
| "分析这段代码" | code-reader |
| "跑一下评估" | eval-runner（读取 spec） |
| "系统发散了" | debug-helper（读取 spec 和 eval 结果后排查） |
| "为什么这段轨迹误差大" | eval-runner → debug-helper → 修复建议 |
| "分析日志" / "看看这段时间发生了什么" | log-analyzer（读取 spec 和 eval 结果） |
| "帮我加一些调试日志" | log-analyzer（Phase 4 插桩设计） |
| "自动优化这个系统" | perf-optimizer（编排 eval-runner + log-analyzer + debug-helper） |
| 后续更多 skill 开发中... | |

---

## 计划开发的 Skill

以下 skill 已规划但尚未开发，按优先级排序：

### 1. slam-paper-analyzer — 论文精读工作流 ⭐⭐⭐⭐⭐

**定位**：系统化论文阅读，提取工程实现关键点

**核心功能**：
- 6 个阶段：基本信息 → 核心方法 → 公式代码映射 → 框架对比 → 实验分析 → 工程评估
- 自动提取论文中的关键公式和算法
- 与现有框架（VINS/ORB-SLAM/FAST-LIO）对比
- 评估工程实现难度和关键点

**解决痛点**：论文读完后不知道如何落地到代码

**预计工作量**：3-4 天

---

### 2. slam-benchmark-evaluator — 多系统评测对比 ⭐⭐⭐⭐

**定位**：批量运行多个 SLAM 系统，横向对比性能

**核心功能**：
- 扩展 eval-runner，支持多框架对比
- 自动运行多个 SLAM 系统（VINS/ORB-SLAM/FAST-LIO 等）
- 生成对比报告和可视化图表
- 支持多个数据集的批量评测

**解决痛点**：手动跑多个系统、整理对比数据耗时

**预计工作量**：2-3 天

---

### 3. slam-config-wizard — 参数配置向导 ⭐⭐⭐

**定位**：根据传感器参数自动生成各框架配置文件

**核心功能**：
- 输入传感器参数（相机内参、IMU 参数、外参等）
- 自动生成 VINS-Mono/Fusion、ORB-SLAM3、FAST-LIO2 等框架的配置
- 参数单位转换和格式适配
- 配置文件验证和检查

**解决痛点**：换框架时要重新写配置，容易出错

**预计工作量**：2 天

---

### 4. slam-code-reviewer — 代码审查工作流 ⭐⭐⭐

**定位**：结构化代码审查，检查 SLAM 特有问题

**核心功能**：
- 基于 code-review-checklist.md
- 检查 SLAM 特有问题（坐标系、时间同步、数值稳定性等）
- 生成结构化审查报告
- 提供修复建议

**解决痛点**：代码审查缺乏 SLAM 领域针对性

**预计工作量**：2 天

---

### 5. slam-architecture-designer — 系统架构设计助手 ⭐⭐

**定位**：引导设计 SLAM 系统架构

**核心功能**：
- 传感器选型建议
- 前端/后端策略选择
- 模块划分和接口设计
- 生成架构文档

**解决痛点**：新手不知道如何从零设计 SLAM 系统

**预计工作量**：2-3 天

---

## 知识库（Knowledge Base）

`references/` 目录下包含 SLAM/VIO 领域的理论知识库，供 Skills 和开发者参考使用。

### 核心知识文档

| 文档 | 内容 | 使用场景 |
|------|------|---------|
| [optimization-theory.md](references/optimization-theory.md) | 优化理论基础 | 分析 Hessian 矩阵、雅可比矩阵、残差分布、权重分布对精度的影响 |
| [filtering-theory.md](references/filtering-theory.md) | 滤波理论基础 | 理解卡尔曼滤波、EKF、MSCKF、IMU 预积分等滤波方法 |
| [formula-cheatsheet.md](references/formula-cheatsheet.md) | 常用公式速查 | 快速查阅 SLAM/VIO 中的核心数学公式 |
| [code-patterns.md](references/code-patterns.md) | 代码模式识别 | 识别 SLAM 代码中的常见模式和最佳实践 |
| [framework-comparison.md](references/framework-comparison.md) | 框架对比 | 对比 VINS、ORB-SLAM、OpenVINS 等主流框架的特点 |

### 知识库的使用方式

1. **Skills 引用**：Skills 在执行时可以引用知识库中的理论进行分析
   - 例如：`slam-debug-helper` 在诊断优化问题时引用 `optimization-theory.md`
   - 例如：分析滤波系统时引用 `filtering-theory.md`

2. **开发者学习**：开发者可以直接阅读这些文档学习 SLAM/VIO 理论

3. **AI 辅助**：AI 助手可以利用这些知识提供更专业的分析和建议

### 知识库的扩展

欢迎贡献更多知识文档，建议的主题：
- 李群与李代数在 SLAM 中的应用
- 图优化与因子图的深入理解
- 传感器标定理论与实践
- 多传感器融合方法
- 深度学习在 SLAM 中的应用

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
│   └── slam-debug-helper/             ← SLAM 系统故障诊断工具
│       ├── SKILL.md                   ← 入口：触发词 + Phase 编排
│       ├── phases/                    ← 4 个 Phase 的指令文件
│       │   ├── phase0-symptom.md      ← 症状分类
│       │   ├── phase1-collect.md      ← 信息收集
│       │   ├── phase2-diagnose.md     ← 根因诊断（决策树）
│       │   └── phase3-verify.md       ← 修复方案
│       └── templates/
│           └── debug-report-template.md  ← 诊断报告模板
│
│   └── slam-log-analyzer/             ← SLAM 日志分析工具
│       ├── SKILL.md                   ← 入口：触发词 + Phase 编排
│       ├── phases/                    ← 5 个 Phase 的指令文件
│       │   ├── phase0-scan.md         ← 日志扫描
│       │   ├── phase1-parse.md        ← 日志解析
│       │   ├── phase2-map.md          ← 代码映射
│       │   ├── phase3-analyze.md      ← 时段分析
│       │   └── phase4-instrument.md   ← 插桩设计
│       └── templates/
│           └── log-analysis-template.md  ← 分析报告模板
│
│   └── slam-perf-optimizer/           ← 性能优化编排器
│       ├── SKILL.md                   ← 入口：触发词 + Phase 编排
│       ├── phases/                    ← 5 个 Phase 的指令文件
│       │   ├── phase0-init.md         ← 初始化
│       │   ├── phase1-build.md        ← 自动构建
│       │   ├── phase2-run.md          ← 自动运行
│       │   ├── phase3-optimize.md     ← 迭代优化
│       │   └── phase4-converge.md     ← 收敛判断
│       └── templates/
│           └── optimization-report-template.md  ← 优化报告模板
│
├── rules/                             ═══ Rules / System Prompts ═══
│   ├── slam-domain-knowledge.md        ← SLAM 领域知识库
│   ├── code-review-checklist.md        ← 代码审查检查清单
│   ├── debug-knowledge.md              ← SLAM 故障诊断知识库
│   └── frameworks/                     ← 框架特化知识（插件）
│       └── vins-debug-patterns.md      ← VINS 系列故障模式
│
├── agents/                            ═══ Agent 角色定义 ═══
│   ├── slam-reviewer.md                ← SLAM 代码审查员
│   └── paper-analyst.md                ← 论文分析专家
│
├── references/                        ═══ 参考资料 ═══
│   ├── framework-comparison.md         ← 主流框架特征对照表
│   ├── formula-cheatsheet.md           ← 常用公式速查
│   ├── code-patterns.md                ← SLAM 代码常见模式识别
│   ├── optimization-theory.md          ← 优化理论基础（Hessian、雅可比、残差、权重）
│   └── filtering-theory.md             ← 滤波理论基础（卡尔曼、EKF、MSCKF、预积分）
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
