# slam-project-profiler

SLAM / VIO / 视觉定位项目的"画像"生成工具。通过交互式问答，让 AI 快速理解特定项目的工作方式，生成结构化的项目规格文件（`project-spec.md`），供其他 skill 读取使用。

## 定位

**基础设施 skill**——其他 skill（debug-helper、eval-runner、log-analyzer 等）执行前都需要读取 `project-spec.md`。本 skill 是唯一生成该文件的入口。

## 触发词

- "了解这个项目"
- "建立项目画像"
- "生成项目规格"
- "profiler"
- "项目初始化"

## 依赖

无（可作为第一个执行的 skill）

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_path | string | ✅ | 项目根目录绝对路径 |

## 输出产物

```
{project}/
└── .specs/
    └── project-spec.md    ← 项目规格文件（自然语言 + 结构化 MD）
```

## 四步法总览

```
Phase 0: 自动扫描      → 扫描项目目录、配置、README、代码结构，形成初步假设
Phase 1: 交互确认      → AI 逐项提出假设，用户确认/纠正/补充
Phase 2: 生成规格      → 汇总确认信息，生成 project-spec.md
Phase 3: 验证          → 用 spec 中的信息尝试读取样本数据，确认可解析性
```

### 依赖关系

```
Phase 0 ──────→ Phase 1 ──────→ Phase 2 ──────→ Phase 3
（扫描）        （确认）         （生成）         （验证）
```

全部顺序执行，不可跳过。Phase 1 是核心交互环节。

## 执行模式

### 模式 A：全量执行（默认）

用户说："帮我了解这个项目" 或 "profiler /path/to/project"

执行流程：
1. 确认项目路径有效
2. 按 Phase 0 → 1 → 2 → 3 顺序执行
3. Phase 1 中逐项与用户交互确认
4. 最终生成 `{project}/.specs/project-spec.md`

### 模式 B：单 Phase 执行

| 用户说 | 执行内容 |
|--------|---------|
| "扫描项目结构" | 仅 Phase 0 |
| "确认项目信息" | 仅 Phase 1（需要 Phase 0 的结果） |
| "重新生成 spec" | Phase 2（需要 Phase 0+1 的信息） |
| "验证 spec" | 仅 Phase 3 |

### 模式 C：更新已有 spec

用户说："更新项目规格" 或 "spec 里数据集路径变了"

执行流程：
1. 读取现有 `{project}/.specs/project-spec.md`
2. 仅针对用户指定的章节重新执行 Phase 0+1+2
3. 保留未变更的内容
4. 覆盖写入更新后的 spec

## Phase 编排详情

| Phase | 文件 | 名称 | 可独立执行 |
|-------|------|------|-----------|
| 0 | `phases/phase0-scan.md` | 自动扫描 | ✅ |
| 1 | `phases/phase1-understand.md` | 交互确认 | ✅（需 Phase 0） |
| 2 | `phases/phase2-generate.md` | 生成规格 | ✅（需 Phase 0+1） |
| 3 | `phases/phase3-verify.md` | 验证 | ✅（需 Phase 2） |

## 输出模板

| 模板文件 | 用途 |
|---------|------|
| `templates/project-spec-template.md` | project-spec.md 的输出格式 |

AI 在生成 spec 时必须严格套用模板格式。

## 全局约定

### 项目路径

- `{project}` 取用户输入的绝对路径
- spec 文件固定存放在 `{project}/.specs/project-spec.md`
- 如果 `.specs/` 目录不存在，自动创建

### spec 版本管理

- spec 文件头部记录生成日期和最后更新日期
- 每次更新时追加更新记录
- 格式：`> 生成日期: {date} | 最后更新: {date}`

### 与其他 skill 的衔接

本 skill 产出的 spec 文件被以下 skill 读取：

| 消费方 skill | 读取的 spec 章节 |
|-------------|-----------------|
| slam-debug-helper | 全部（理解项目上下文） |
| slam-eval-runner | ## 数据集 / ## 真值 / ## 系统输出 / ## 评估 |
| slam-log-analyzer | ## 日志 / ## 系统输出 |
| slam-perf-optimizer | 全部（编排需要） |
| slam-code-reader | 可选（补充项目上下文） |

### 错误处理

当项目路径无效时：

```
⚠️ 无法执行 slam-project-profiler

原因: 项目路径不存在或不是有效目录:
  - {project_path}

请确认路径后重试。
```

当项目已有 spec 时，执行更新模式前确认：

```
📋 检测到已有项目规格文件:
  - {project}/.specs/project-spec.md
  - 生成日期: {date}

请选择:
  1. 更新指定章节（推荐）
  2. 完全重新生成
  3. 取消
```
