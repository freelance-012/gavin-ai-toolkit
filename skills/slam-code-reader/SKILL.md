# slam-code-reader

SLAM / VIO / 视觉定位算法代码解读工具集。按照"七步法"系统性地剖析算法工程代码，将"从零到建立全局认知"的时间从 2-3 天压缩到半天。

## 适用范围

任何 SLAM、VIO、视觉惯性导航、传感器融合相关的 C++/Python 代码库，包括但不限于：
- 单目/双目/RGB-D 视觉 SLAM
- VIO（视觉惯性里程计）
- 激光 SLAM / 激光-视觉融合
- 紧耦合/松耦合多传感器融合
- 基于优化/基于滤波的状态估计器

## 触发词

- "分析 XX 代码"
- "解读 XX 方案"
- "阅读 XX 工程代码"
- "帮我读懂这套 SLAM/VIO 代码"
- "生成代码分析报告"

## 七步法总览

```
Phase 0: 资料收集          → 收集论文 PDF、文档、第三方解读
Phase 1: 代码拓扑扫描       → 目录结构、模块职责、依赖关系、入口点
Phase 2: 数据流追踪         → 从传感器输入到位姿输出的完整 pipeline
Phase 3: 模块优先级标注     → P0/P1/P2/P3 分类，确定精读重点
Phase 4: 核心模块深度分析   → 公式↔代码逐行对照精读
Phase 5: 参数清单提取       → 全部可调参数速查表
Phase 6: 阅读路线图         → 推荐阅读顺序 + 快速验证建议
```

## 依赖关系

```
Phase 0 ──────────→ Phase 4, Phase 6
Phase 1 ──────────→ Phase 2, 3, 4, 5, 6
Phase 2 ──────────→ Phase 3, 4, 6
Phase 3 ──────────→ Phase 4, 6
Phase 4 ──────────→ Phase 6
Phase 5 ──────────→ Phase 6
```

## 输出目录约定

所有产出统一输出到：

```
{项目根目录}/{仓库名}-code-analysis/
├── 00_资料清单.md              ← Phase 0
├── docs/                       ← Phase 0 (实体文件)
│   ├── papers/
│   │   ├── {Year}_{Venue}_{FirstAuthor}_{ShortTitle}.pdf  # 主论文
│   │   └── related/        # 命名: {Year}_{Venue}_{FirstAuthor}_{ShortTitle}.pdf
│   ├── docs-online/        # 命名: {source}_{topic}.md
│   └── third-party/        # 命名: {platform}_{author}_{topic}.md
├── 01_拓扑结构分析.md           ← Phase 1
├── 02_数据流追踪.md             ← Phase 2
├── 03_模块优先级清单.md         ← Phase 3
├── 04/                         ← Phase 4 (每模块一份)
│   └── {module}-deep-dive.md
├── 05_参数清单.md               ← Phase 5
└── 06_阅读路线图.md             ← Phase 6
```

### 04/ 文档拆分规则（主文档 + 子文档）

**每个 S 锚点（来自 03 清单 §7 的函数级路线）对应一篇独立主文档，不得多锚点合并进一篇。**

但一个主文档（如 `S13_UpdaterMSCKF`）内部往往调用了**更核心、更复杂的内部模块**（如零空间投影、测量压缩、三角化+GN 等），这些内部模块本身值得独立精读。规则如下：

- **主文档（Sxx）**：聚焦该模块的**编排逻辑与调用链**，对内部复杂子模块只写"作用 + 调用位置 + 源码行号"，不展开其内部数学/逐行。
- **子文档（Sxxa / Sxxb / Sxxc …）**：当某个内部模块足够核心/复杂（建议：含 ≥50 行非平凡数学、或自身有完整公式体系、或后续会被反复查阅）时，拆为独立子文档，编号沿用 `Sxx + 小写字母后缀`。
  - 命名：`04/S13a_UpdaterHelper-nullspace-projection.md`、`04/S13b_UpdaterHelper-measurement-compress.md`、`04/S13c_FeatureInitializer-triangulation.md` 等。
  - 子文档套用与主文档相同的 7-section 模板，只是标题前缀用 `Sxxa` 这类编号。
- **待补充清单（lazy 机制）**：如果写主文档时某个内部模块**暂不需要详细展开**，不要强行合并，也不要错误标注为"下沉到无关模块"（例如不可把 UpdaterHelper 的内部函数标成"下沉 S14"，S14 是另一个独立模块）。正确做法是：
  1. 在主文档末尾加一节 **"待详细补充项（子文档）"**，逐项列出：内部模块名、归属文件:行号、对应论文、建议子文档编号（Sxxa 等）。
  2. 后续用户需要该细节时，再补写对应的 `Sxxa` 子文档。
- **编号一致性**：所有 S 编号（含 a/b/c 后缀）必须在 `03_模块优先级清单.md` 的映射表中登记，便于回溯。子文档不应复用/抢占其他主锚点的编号（如 S14 专属于 UpdaterSLAM，不可被 UpdaterMSCKF 的内部模块占用）。

## 执行模式

### 模式 A：全量执行（默认）

用户说："分析 D:/xxx-project"

执行流程：
1. 确认仓库路径有效
2. 创建 `{仓库名}-code-analysis/` 目录
3. 按 0 → 1 → 2 → 3 → 4 → 5 → 6 顺序依次执行每个 Phase
4. 每个 Phase 执行前检查依赖是否满足：
   - 依赖文件存在 → 继续执行
   - 依赖文件缺失 → **停止**，告知用户缺少什么、如何补救
5. 全部完成后，展示最终产物清单

### 模式 B：单 Phase 执行

用户说："只跑 Phase 2" 或 "追踪数据流"

执行流程：
1. 加载对应 phase 的指令文件 (`phases/phase{N}-{name}.md`)
2. 检查该 Phase 的前置依赖
3. 依赖满足 → 执行；不满足 → 停止并提示
4. 仅产出该 Phase 对应的文件

### 模式 C：选择性连续执行

用户说："跑 Phase 1 到 Phase 3"

执行流程：
1. 从指定起始 Phase 开始
2. 按顺序执行到指定结束 Phase
3. 同样遵循依赖检查规则

## 错误处理规范

当依赖缺失时，统一使用以下格式回复：

```
⚠️ [Phase X] 无法执行

原因: 缺少必要的前置产出文件:
  - {仓库名}-code-analysis/YY_文件名.md

解决方案（任选其一）:
  1. 先执行 Phase Y 生成该文件
  2. 手动创建该文件放到输出目录中
  3. 如果已有类似文件但名称不同，请告诉我路径

是否需要我帮你执行 Phase Y？(Y/n)
```

## Phase 编排详情

各 Phase 的具体指令定义在 `phases/` 目录下的独立文件中：

| Phase | 文件 | 名称 | 是否可独立 |
|-------|------|------|-----------|
| 0 | `phases/phase0-collect.md` | 资料收集 | ✅ |
| 1 | `phases/phase1-topology.md` | 代码拓扑扫描 | ✅ |
| 2 | `phases/phase2-dataflow.md` | 数据流追踪 | ✅ |
| 3 | `phases/phase3-priority.md` | 模块优先级标注 | ✅ |
| 4 | `phases/phase4-deep-dive.md` | 核心模块深度分析 | ✅ |
| 5 | `phases/phase5-params.md` | 参数清单提取 | ✅ |
| 6 | `phases/phase6-roadmap.md` | 阅读路线图 | ✅ |

**加载方式**：执行到某 Phase 时，读取对应的 `.md` 文件获取完整指令。

## 输出文档模板

各 Phase 的输出格式模板定义在 `templates/` 目录下：

| 模板文件 | 对应 Phase | 用途 |
|---------|-----------|------|
| `templates/resource-list-template.md` | Phase 0 | 资料清单格式 |
| `templates/topology-report-template.md` | Phase 1 | 拓扑分析报告格式 |
| `templates/dataflow-report-template.md` | Phase 2 | 数据流报告格式 |
| `templates/priority-list-template.md` | Phase 3 | 优先级清单格式 |
| `templates/deep-dive-template.md` | Phase 4 | 模块精读文档格式 (7-section) |
| `templates/param-list-template.md` | Phase 5 | 参数清单格式 |
| `templates/roadmap-template.md` | Phase 6 | 阅读路线图格式 |

AI 在生成报告时必须严格套用对应模板的格式。

## 全局约定

### 代码版本记录（强制）

**所有 Phase 的输出报告头部必须包含目标代码仓库的版本信息。**

- Phase 1 执行时自动检测并记录 git commit hash
- 后续所有 Phase (0, 2, 3, 4, 5, 6) 继承该版本信息，写入各自报告头部
- 如果工作区有未提交修改，必须标注 `DIRTY`
- **目的**：保证分析结果可复现 —— 任何时候都能通过 commit hash 精确回溯到分析时的代码版本

### 输出目录命名规则

输出目录名使用 `{仓库名}-code-analysis/`，其中 `{仓库名}` 取自仓库根目录的文件夹名（非完整路径）。
