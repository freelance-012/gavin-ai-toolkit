# AI Toolkit 组件架构说明

本文档详细说明 AI Toolkit 中五大核心组件（Knowledge Base、Rules、Skills、Agents、Hooks）的定位、使用场景和相互关系。

## 目录

- [概述](#概述)
- [组件详解](#组件详解)
  - [Knowledge Base（知识库）](#knowledge-base知识库)
  - [Rules（规则）](#rules规则)
  - [Skills（技能）](#skills技能)
  - [Agents（智能体）](#agents智能体)
  - [Hooks（钩子）](#hooks钩子)
- [组件对比](#组件对比)
- [组件关系图](#组件关系图)
- [使用决策指南](#使用决策指南)
- [实例说明](#实例说明)

---

## 概述

AI Toolkit 采用分层架构设计，将不同职责分离到五个核心组件中：

| 组件 | 核心问题 | 定位 |
|------|---------|------|
| **Knowledge Base** | 知道什么 | 领域知识、理论、事实 |
| **Rules** | 应该怎么做 | 约束、规范、检查清单 |
| **Skills** | 如何执行任务 | 可执行的工作流 |
| **Agents** | 以什么身份执行 | 角色定义、专业身份 |
| **Hooks** | 何时自动触发 | 事件监听、自动响应 |

这种设计遵循"关注点分离"原则，使系统更易维护、扩展和复用。

---

## 组件详解

### Knowledge Base（知识库）

**定位**：存储领域知识、理论、事实、参考资料

#### 特征

- **静态性**：内容相对稳定，不随执行变化
- **参考性**：被其他组件引用，不直接执行
- **专业性**：包含深度的领域知识
- **可验证性**：基于理论、文献、最佳实践

#### 内容类型

```markdown
knowledge/
├── optimization-theory/          # 优化理论
│   ├── hessian-matrix.md         # Hessian 矩阵理论
│   ├── jacobian-matrix.md        # 雅可比矩阵理论
│   ├── residual-analysis.md      # 残差分析
│   └── weight-distribution.md    # 权重分布
│
├── slam-mathematics/             # SLAM 数学基础
│   ├── lie-group.md              # 李群与李代数
│   ├── kalman-filter.md          # 卡尔曼滤波
│   └── graph-optimization.md     # 图优化
│
├── sensor-models/                # 传感器模型
│   ├── camera-model.md           # 相机模型
│   ├── imu-model.md              # IMU 模型
│   └── lidar-model.md            # LiDAR 模型
│
└── best-practices/               # 最佳实践
    ├── system-design.md          # 系统设计
    ├── parameter-tuning.md       # 参数调优
    └── debugging-guide.md        # 调试指南
```

#### 使用场景

✅ **适合使用 Knowledge Base**：
- 需要理论支撑决策时
- 需要解释"为什么"时
- 需要参考标准和最佳实践时
- 需要深度学习某个领域时

❌ **不适合使用 Knowledge Base**：
- 需要执行具体任务时（用 Skills）
- 需要强制规范时（用 Rules）
- 需要自动触发时（用 Hooks）

#### 示例

```markdown
# knowledge/optimization-theory/hessian-matrix.md

## Hessian 矩阵与优化质量

### 理论基础

在 SLAM 后端优化中，Hessian 矩阵 H 定义为：

H = J^T * W * J

其中：
- J：雅可比矩阵（n×m）
- W：权重矩阵（n×n）
- H：Hessian 矩阵（m×m）

### 条件数分析

条件数 κ(H) = λ_max / λ_min

| 条件数范围 | 优化质量 | 精度影响 |
|-----------|---------|---------|
| κ < 100 | 良好 | 高精度 |
| 100 ≤ κ < 10^4 | 一般 | 中等精度 |
| 10^4 ≤ κ < 10^6 | 较差 | 精度下降 |
| κ ≥ 10^6 | 病态 | 严重退化 |

### 诊断方法

1. 计算 Hessian 矩阵的特征值
2. 分析条件数分布
3. 识别接近零的特征值对应的状态量
4. 判断是否存在冗余参数或弱约束

### 改进策略

- **正则化**：H' = H + λI（Levenberg-Marquardt）
- **降维**：边缘化弱约束状态
- **重新参数化**：改进参数化方式
```

---

### Rules（规则）

**定位**：定义约束、规范、检查清单、决策指南

#### 特征

- **约束性**：强制执行某些标准
- **判断性**：提供是/否判断依据
- **可检查性**：可以验证是否遵守
- **稳定性**：规则相对稳定，不频繁变化

#### 内容类型

```markdown
rules/
├── code-review/                  # 代码审查规则
│   ├── slam-checklist.md         # SLAM 代码审查清单
│   ├── optimization-checklist.md # 优化代码审查清单
│   └── naming-convention.md      # 命名规范
│
├── debugging/                    # 调试规则
│   ├── error-handling.md         # 错误处理规范
│   ├── logging-standards.md      # 日志规范
│   └── troubleshooting-flow.md   # 故障排查流程
│
└── best-practices/               # 最佳实践规则
    ├── parameter-tuning.md       # 参数调优规则
    ├── numerical-stability.md    # 数值稳定性规则
    └── thread-safety.md          # 线程安全规则
```

#### 使用场景

✅ **适合使用 Rules**：
- 需要强制执行标准时
- 需要做合规性检查时
- 需要提供决策依据时
- 需要统一团队实践时

❌ **不适合使用 Rules**：
- 需要深度理论知识时（用 Knowledge Base）
- 需要执行复杂流程时（用 Skills）
- 需要角色扮演时（用 Agents）

#### 示例

```markdown
# rules/code-review/slam-checklist.md

## SLAM 代码审查清单

### 数值稳定性

- [ ] 矩阵求逆前检查条件数
- [ ] 使用 SVD 代替直接求逆（病态矩阵）
- [ ] 避免除以接近零的数
- [ ] 使用双精度浮点数（关键计算）

### 坐标系统一

- [ ] 明确定义世界坐标系（ENU/NED/FLU）
- [ ] 所有变换使用统一的坐标系
- [ ] 外参变换正确（T_cam_imu vs T_imu_cam）
- [ ] 旋转表示一致（四元数/旋转矩阵）

### 时间同步

- [ ] IMU 和相机时间戳对齐
- [ ] 处理时间延迟
- [ ] 使用统一的时间基准
- [ ] 检查时间戳单位（秒/毫秒/纳秒）

### 优化相关

- [ ] 雅可比矩阵解析推导（非数值差分）
- [ ] Hessian 矩阵正定性检查
- [ ] 使用鲁棒核函数（Huber/Cauchy）
- [ ] 边缘化时保持稀疏性
```

---

### Skills（技能）

**定位**：定义可执行的工作流，包含多个阶段和步骤

#### 特征

- **可执行性**：可以被触发和执行
- **流程性**：包含多个阶段和步骤
- **输入输出**：有明确的输入和输出
- **可复用性**：可以在不同项目中使用

#### 内容类型

```markdown
skills/
├── slam-code-reader/             # 代码解读技能
│   ├── SKILL.md                  # 技能定义
│   ├── phases/                   # 阶段定义
│   │   ├── phase0-collect.md
│   │   ├── phase1-topology.md
│   │   └── ...
│   └── templates/                # 输出模板
│
├── slam-debug-helper/            # 调试技能
│   ├── SKILL.md
│   ├── phases/
│   │   ├── phase0-symptom.md
│   │   ├── phase1-collect.md
│   │   ├── phase2-diagnose.md
│   │   └── phase3-verify.md
│   └── templates/
│
└── slam-perf-optimizer/          # 性能优化技能
    ├── SKILL.md
    ├── phases/
    │   ├── phase0-init.md
    │   ├── phase1-build.md
    │   ├── phase2-run.md
    │   ├── phase3-optimize.md
    │   └── phase4-converge.md
    └── templates/
```

#### 使用场景

✅ **适合使用 Skills**：
- 需要完成具体任务时
- 需要多步骤流程时
- 需要标准化工作流时
- 需要可复用的执行模板时

❌ **不适合使用 Skills**：
- 只需要提供知识时（用 Knowledge Base）
- 只需要约束行为时（用 Rules）
- 只需要自动触发时（用 Hooks）

#### 示例

```markdown
# skills/slam-debug-helper/SKILL.md

## 技能定义

**名称**：SLAM 调试助手
**触发词**：调试、排查问题、分析误差
**输入**：项目路径、问题描述
**输出**：诊断报告、修复建议

## 执行流程

### Phase 0: 症状收集
1. 收集问题描述
2. 确定问题类型（漂移/发散/丢失）
3. 收集相关日志和数据

### Phase 1: 数据分析
1. 分析轨迹误差
2. 分析日志模式
3. 检查参数配置

### Phase 2: 根因诊断
1. 使用决策树定位根因
2. 引用知识库理论分析
3. 生成诊断报告

### Phase 3: 修复建议
1. 提出修复方案
2. 验证修复效果
3. 输出修复报告

## 依赖

- Knowledge: optimization-theory/, slam-mathematics/
- Rules: code-review/slam-checklist.md
```

---

### Agents（智能体）

**定位**：定义角色、专业身份、行为模式

#### 特征

- **角色性**：代表特定专家角色
- **专业性**：具有特定领域的专业知识
- **交互性**：定义与用户的交互方式
- **可组合性**：可以被 skills 调用

#### 内容类型

```markdown
agents/
├── slam-expert.md                # SLAM 专家
├── optimization-theorist.md      # 优化理论专家
├── code-reviewer.md              # 代码审查员
├── performance-analyst.md        # 性能分析师
└── system-architect.md           # 系统架构师
```

#### 使用场景

✅ **适合使用 Agents**：
- 需要特定专家视角时
- 需要特定交互风格时
- 需要角色扮演时
- 需要专业化回答时

❌ **不适合使用 Agents**：
- 只需要执行任务时（用 Skills）
- 只需要提供知识时（用 Knowledge Base）
- 只需要约束行为时（用 Rules）

#### 示例

```markdown
# agents/optimization-theorist.md

## 角色定义

**名称**：优化理论专家
**专业领域**：非线性优化、图优化、数值方法
**背景**：10 年 SLAM 后端优化经验

## 行为准则

1. **理论优先**：基于数学理论分析问题
2. **严谨推导**：提供完整的数学推导
3. **实践结合**：理论联系实际工程问题
4. **深入浅出**：用通俗语言解释复杂概念

## 专业知识

- Hessian 矩阵分析与改进
- 雅可比矩阵计算方法
- 鲁棒优化理论
- 稀疏矩阵技术
- 边缘化与 Schur 补

## 交互风格

- 使用数学公式说明问题
- 提供理论依据和引用
- 给出改进建议和代码示例
- 解释"为什么"而不仅是"怎么做"

## 典型问题

**用户**：为什么我的优化结果不稳定？

**专家回答**：
让我们从理论角度分析这个问题...

首先，检查 Hessian 矩阵的条件数：
κ(H) = λ_max / λ_min

如果 κ > 10^6，说明问题是病态的...

根据 Levenberg-Marquardt 理论...

建议采用以下改进策略...
```

---

### Hooks（钩子）

**定位**：定义事件监听器和自动触发的动作

#### 特征

- **事件驱动**：响应特定事件
- **自动化**：无需人工干预
- **透明性**：在后台默默工作
- **轻量级**：执行简单动作

#### 内容类型

```markdown
hooks/
├── session-logger/               # 会话日志记录
│   ├── session-start.md          # 会话开始时记录
│   ├── tool-use.md               # 工具使用时记录
│   └── session-end.md            # 会话结束时生成报告
│
├── auto-format/                  # 自动格式化
│   └── on-save.md                # 保存时自动格式化
│
└── notification/                 # 通知钩子
    └── long-task.md              # 长任务完成时通知
```

#### 使用场景

✅ **适合使用 Hooks**：
- 需要在特定事件发生时自动执行时
- 需要监控和记录时
- 需要自动响应时
- 需要无感知的后台任务时

❌ **不适合使用 Hooks**：
- 需要用户主动触发时（用 Skills）
- 需要复杂流程时（用 Skills）
- 需要提供知识时（用 Knowledge Base）

#### 示例

```markdown
# hooks/session-logger/session-start.md

## 钩子定义

**触发事件**：会话开始
**执行时机**：用户开始新会话时
**优先级**：高

## 执行动作

1. 创建会话目录
   ```
   logs/{timestamp}_{session_id}/
   ```

2. 初始化日志文件
   ```
   session.log
   config.json
   ```

3. 记录会话元数据
   - 时间戳
   - 用户信息
   - 工作目录
   - 环境配置

4. 加载项目规格
   - 读取 .specs/project-spec.md
   - 验证必需配置

## 输出

- 会话目录已创建
- 日志文件已初始化
- 项目配置已加载
```

---

## 组件对比

| 维度 | Knowledge Base | Rules | Skills | Agents | Hooks |
|------|---------------|-------|--------|--------|-------|
| **核心问题** | 知道什么 | 应该怎么做 | 如何执行 | 以什么身份 | 何时触发 |
| **内容性质** | 知识、理论 | 约束、规范 | 流程、步骤 | 角色、身份 | 事件、动作 |
| **执行方式** | 被引用 | 被遵循 | 被执行 | 被扮演 | 自动触发 |
| **交互方式** | 被动参考 | 被动遵循 | 主动执行 | 主动交互 | 自动执行 |
| **复杂度** | 中-高 | 低-中 | 高 | 中 | 低 |
| **变化频率** | 低 | 低 | 中 | 低 | 低 |
| **依赖关系** | 独立 | 独立 | 依赖 Knowledge/Rules | 依赖 Knowledge | 独立 |

### 详细对比

#### 1. Knowledge Base vs Rules

| 对比项 | Knowledge Base | Rules |
|--------|---------------|-------|
| **目的** | 提供知识 | 强制执行 |
| **灵活性** | 灵活参考 | 严格遵守 |
| **验证方式** | 理解应用 | 检查清单 |
| **典型内容** | 理论、公式、推导 | 清单、规范、约束 |
| **失败后果** | 理解偏差 | 违反规范 |

**选择指南**：
- 需要解释"为什么" → Knowledge Base
- 需要强制"必须做" → Rules

#### 2. Skills vs Agents

| 对比项 | Skills | Agents |
|--------|--------|--------|
| **目的** | 执行任务 | 提供视角 |
| **执行方式** | 按流程执行 | 按角色交互 |
| **输出** | 具体产物 | 专业建议 |
| **复杂度** | 多步骤流程 | 单一角色 |
| **典型场景** | 调试、评估、优化 | 咨询、审查、分析 |

**选择指南**：
- 需要完成任务 → Skills
- 需要专业建议 → Agents

#### 3. Skills vs Hooks

| 对比项 | Skills | Hooks |
|--------|--------|-------|
| **触发方式** | 用户主动 | 事件自动 |
| **交互性** | 高 | 无 |
| **复杂度** | 高 | 低 |
| **可见性** | 高 | 低（后台） |
| **典型场景** | 调试、评估 | 日志、监控 |

**选择指南**：
- 需要用户参与 → Skills
- 需要自动执行 → Hooks

---

## 组件关系图

```
┌─────────────────────────────────────────────────────────────┐
│                         用户请求                              │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  Hooks（自动触发层）                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ session-     │  │ auto-format  │  │ notification │      │
│  │ logger       │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└────────────────┬────────────────────────────────────────────┘
                 │ 触发
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  Skills（任务执行层）                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ code-reader  │  │ debug-helper │  │ perf-        │      │
│  │              │  │              │  │ optimizer    │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          │ 引用             │ 使用             │ 调用
          ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  Knowledge Base │ │     Rules       │ │     Agents      │
│  （知识层）      │ │   （规范层）     │ │   （角色层）     │
│                 │ │                 │ │                 │
│ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │
│ │ optimization│ │ │ │ code-review │ │ │ │ slam-expert │ │
│ │ -theory/    │ │ │ │ -checklist  │ │ │ │             │ │
│ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │
│ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │
│ │ slam-math/  │ │ │ │ debugging/  │ │ │ │ optimization│ │
│ │             │ │ │ │ guidelines  │ │ │ │ -theorist   │ │
│ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### 数据流向

```
用户请求 → Hooks（自动触发）
              ↓
         Skills（执行任务）
              ↓
    ┌─────────┼─────────┐
    ↓         ↓         ↓
Knowledge   Rules    Agents
（理论知识） （规范）  （角色）
    ↓         ↓         ↓
    └─────────┼─────────┘
              ↓
         执行结果 → 用户
```

---

## 使用决策指南

### 决策树

```
你需要什么？
│
├─ 存储理论知识 → Knowledge Base
│
├─ 强制执行规范 → Rules
│
├─ 执行具体任务 → Skills
│  │
│  ├─ 需要多步骤流程 → 创建 Skill
│  └─ 需要自动化 → Hooks
│
├─ 提供专业视角 → Agents
│
└─ 自动响应事件 → Hooks
```

### 选择矩阵

| 需求场景 | 推荐组件 | 理由 |
|---------|---------|------|
| 解释 Hessian 矩阵理论 | Knowledge Base | 需要深度理论知识 |
| 强制代码审查清单 | Rules | 需要强制执行标准 |
| 自动调试 SLAM 系统 | Skills | 需要多步骤执行流程 |
| 以专家身份回答问题 | Agents | 需要专业视角 |
| 自动记录会话日志 | Hooks | 需要自动触发 |
| 分析优化问题根因 | Skills + Knowledge | 需要流程 + 理论 |
| 检查代码是否符合规范 | Rules + Skills | 需要规范 + 执行 |
| 提供专业咨询建议 | Agents + Knowledge | 需要角色 + 知识 |

---

## 实例说明

### 实例 1：分析 SLAM 系统性能下降

**场景**：用户报告 SLAM 系统精度下降，需要分析原因

**组件使用**：

1. **Skills**：slam-debug-helper
   - 执行调试流程
   - 收集数据、分析、诊断

2. **Knowledge Base**：optimization-theory/
   - 引用 Hessian 矩阵理论
   - 分析条件数与精度的关系
   - 解释病态问题

3. **Rules**：debugging-guidelines.md
   - 遵循调试流程
   - 检查常见问题

4. **Agents**：optimization-theorist
   - 以优化专家身份分析
   - 提供理论解释

**执行流程**：

```
用户：系统精度下降，帮我分析原因

↓ 触发

Skill: slam-debug-helper
  Phase 0: 收集症状
  Phase 1: 分析数据
    ↓ 引用 Knowledge: optimization-theory/hessian-matrix.md
    ↓ 发现 Hessian 条件数 > 10^6
  Phase 2: 诊断根因
    ↓ 使用 Agent: optimization-theorist
    ↓ 诊断为病态优化问题
    ↓ 遵循 Rules: debugging-guidelines.md
  Phase 3: 生成报告

输出：诊断报告 + 修复建议
```

### 实例 2：自动记录开发会话

**场景**：自动记录所有开发会话，便于回溯

**组件使用**：

1. **Hooks**：session-logger
   - 会话开始时自动创建目录
   - 工具使用时自动记录
   - 会话结束时生成报告

**执行流程**：

```
用户开始会话

↓ 触发 Hook: session-start

Hook 执行：
  1. 创建 logs/{timestamp}/ 目录
  2. 初始化 session.log
  3. 加载项目配置

用户执行操作...

↓ 触发 Hook: tool-use

Hook 执行：
  1. 记录工具调用
  2. 记录参数
  3. 记录结果

用户结束会话

↓ 触发 Hook: session-end

Hook 执行：
  1. 生成会话摘要
  2. 统计工具使用情况
  3. 输出报告

输出：会话日志 + 统计报告
```

### 实例 3：代码审查

**场景**：审查 SLAM 代码是否符合规范

**组件使用**：

1. **Skills**：code-reviewer
   - 执行审查流程
   - 逐项检查

2. **Rules**：slam-checklist.md
   - 提供检查清单
   - 定义审查标准

3. **Knowledge Base**：best-practices/
   - 提供参考标准
   - 解释最佳实践

4. **Agents**：code-reviewer
   - 以审查员身份
   - 提供专业意见

**执行流程**：

```
用户：帮我审查这段代码

↓ 触发

Skill: code-reviewer
  Phase 0: 读取代码
  Phase 1: 逐项检查
    ↓ 遵循 Rules: slam-checklist.md
    ↓ ✓ 数值稳定性检查通过
    ↓ ✗ 坐标系统一检查失败
    ↓ 引用 Knowledge: best-practices/coordinate-system.md
  Phase 2: 生成报告
    ↓ 使用 Agent: code-reviewer
    ↓ 提供专业改进建议

输出：审查报告 + 改进建议
```

---

## 总结

AI Toolkit 的五大组件各有明确的定位和使用场景：

- **Knowledge Base**：存储理论知识，回答"为什么"
- **Rules**：定义规范约束，回答"必须做什么"
- **Skills**：执行具体任务，回答"怎么做"
- **Agents**：提供专业视角，回答"以什么身份"
- **Hooks**：自动响应事件，回答"何时触发"

正确理解和使用这些组件，可以构建出结构清晰、易于维护、高度可复用的 AI 工具系统。
