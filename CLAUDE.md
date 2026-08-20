# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目性质

这是一个 **AI 能力资产库**（纯 Markdown 文档仓库），不是可编译的代码项目。没有构建系统、没有测试框架、没有编译依赖。内容用于 CodeBuddy / Claude Code 等 AI 协作工具的标准化工作流复用，核心领域是 SLAM/VIO 算法研发辅助。

**设计原则**：AI 是执行者，用户是定义者——skill 不预设领域假设，而是读取用户提供的项目规格（spec）文件工作。

## 常用命令

```bash
# 部署（Linux/macOS）
./deploy.sh <platform> <scope> [project_path]
# platform: codebuddy | claude
# scope:    user | project

# 示例
./deploy.sh claude user                              # 全局部署到 Claude Code
./deploy.sh codebuddy project /path/to/project       # 项目级部署到 CodeBuddy

# Windows 对应使用 deploy.bat
```

部署脚本自动遍历 `skills/` 下所有 skill 进行部署。

## 核心架构

### Skill 清单

| Skill | 入口 | 定位 | 产出 |
|-------|------|------|------|
| slam-code-reader | `skills/slam-code-reader/SKILL.md` | SLAM 代码解读（七步法） | `{仓库名}-code-analysis/` |
| slam-project-profiler | `skills/slam-project-profiler/SKILL.md` | 项目画像生成（基础设施） | `{project}/.specs/project-spec.md` |

### Skill 组合关系

```
slam-project-profiler → 生成 project-spec.md
         ↓
slam-code-reader      → 可选读取 spec 补充上下文
         ↓
（后续 skill 将读取 spec 工作：debug-helper, eval-runner, log-analyzer 等）
```

### 项目规格机制

所有面向运行时的 skill 通过读取 `{project}/.specs/project-spec.md` 理解项目。该文件由 slam-project-profiler 通过交互式问答生成，内容包括数据集格式、真值格式、日志体系、评估方式等。

### 目录职责

| 目录 | 用途 |
|------|------|
| `skills/` | 可执行工作流定义（SKILL.md 入口 + phases/ 子步骤 + templates/ 输出模板） |
| `rules/` | 领域知识、审查检查清单等非执行性规范 |
| `agents/` | Agent 角色定义（slam-reviewer、paper-analyst） |
| `references/` | 参考资料（框架对比、公式速查、代码模式识别） |
| `archives/` | 历史分析报告归档 |

### 部署机制

- **CodeBuddy**：`skills/` 下每个 skill 目录 symlink 到 `~/.codebuddy/skills/`
- **Claude Code**：将每个 skill 的 SKILL.md 和 phases/*.md 展平复制为 `~/.claude/commands/{skill_name}*.md`

## 关键约定

### slam-code-reader 特有

- 输出目录：`{仓库名}-code-analysis/`，`{仓库名}` 取仓库根目录文件夹名
- Phase 4 文档拆分：每个 S 锚点一篇主文档，复杂子模块拆为 `Sxxa/Sxxb` 子文档
- 代码版本记录：所有报告头部记录 git commit hash，工作区不干净标注 `DIRTY`

### 新增内容

- **新 Skill**：`skills/` 下新建目录 → 写 SKILL.md → 可选 phases/ + templates/ → 更新 README
- **新 Rule**：`rules/` 下新建 .md
- **新 Agent**：`agents/` 下新建 .md
