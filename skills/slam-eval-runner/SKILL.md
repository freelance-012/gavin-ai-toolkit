# slam-eval-runner

SLAM/VIO 轨迹评估工具。按照用户在 project-spec.md 中定义的评估方式运行评估，生成误差时序分析，标注异常区间。

## 定位

**基础能力 skill**——为 debug-helper、log-analyzer、perf-optimizer 提供量化评估能力。

**核心原则**：不自创指标，完全按用户定义的评估脚本和指标工作。

## 触发词

- "跑一下评估"
- "评估轨迹精度"
- "计算误差"
- "看一下精度"
- "eval"

## 依赖

需要 project-spec.md（由 slam-project-profiler 生成）

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_path | string | ✅ | 项目根目录绝对路径 |
| traj_file | string | ⬜ | 轨迹文件路径（如不指定，使用 spec 中默认路径） |
| gt_file | string | ⬜ | 真值文件路径（如不指定，使用 spec 中默认路径） |

## 输出产物

```
{project}/.specs/eval-results/
├── {timestamp}/
│   ├── eval-report.md              # 评估报告
│   ├── error-timeseries.csv        # 误差时序数据
│   └── error-plot.png              # 误差时序图（如果能生成）
└── latest -> {timestamp}/          # 软链接到最新结果
```

## 三步法总览

```
Phase 0: 读取配置      → 从 spec 中读取评估脚本、轨迹、真值等信息
Phase 1: 运行评估      → 执行用户评估脚本，收集输出
Phase 2: 时序分析      → 生成误差时序曲线，标注异常区间
Phase 3: 生成报告      → 汇总评估结果
```

### 依赖关系

```
Phase 0 ──────→ Phase 1 ──────→ Phase 2 ──────→ Phase 3
（读配置）       （运行评估）      （时序分析）      （生成报告）
```

## 执行模式

### 模式 A：完整评估（默认）

用户说："跑一下评估" 或 "eval"

执行流程：
1. 检查 spec 文件是否存在
2. 按 Phase 0 → 1 → 2 → 3 顺序执行
3. 生成评估报告

### 模式 B：指定轨迹评估

用户说："评估 /path/to/trajectory.csv"

执行流程：
1. 使用指定的轨迹文件
2. 真值文件从 spec 中读取
3. 执行评估

### 模式 C：仅时序分析

用户说："分析误差时序" 或 "标注异常区间"

执行流程：
1. 假设已有评估结果（error-timeseries.csv）
2. 仅执行 Phase 2 的时序分析

## Phase 编排详情

| Phase | 文件 | 名称 | 可独立执行 |
|-------|------|------|-----------|
| 0 | `phases/phase0-spec.md` | 读取配置 | ✅ |
| 1 | `phases/phase1-run.md` | 运行评估 | ✅（需 Phase 0） |
| 2 | `phases/phase2-timeseries.md` | 时序分析 | ✅（需评估数据） |
| 3 | `phases/phase3-report.md` | 生成报告 | ✅（需 Phase 2） |

## 输出模板

| 模板文件 | 用途 |
|---------|------|
| `templates/eval-report-template.md` | 评估报告格式 |

## 全局约定

### 评估结果存储

- 每次评估结果存放在 `{project}/.specs/eval-results/{timestamp}/`
- `{timestamp}` 格式：`YYYYMMDD_HHMMSS`
- `latest` 软链接指向最新结果
- 便于对比多次评估结果

### 误差时序数据格式

`error-timeseries.csv` 格式：

```csv
timestamp,error,error_x,error_y,error_z,error_roll,error_pitch,error_yaw
1623456789.123,0.052,0.031,0.022,0.041,0.001,0.002,0.003
1623456789.223,0.054,0.033,0.024,0.042,0.001,0.002,0.003
...
```

### 异常区间定义

误差异常区间的判定标准：
- **默认**：误差 > 2倍平均误差 或 > 用户指定阈值
- 连续 N 帧（默认 N=10）超过阈值视为一个异常区间
- 异常区间合并：间隔 < 1秒的相邻异常区间合并

### 与其他 skill 的衔接

本 skill 产出的评估结果被以下 skill 读取：

| 消费方 skill | 读取的内容 |
|-------------|-----------|
| slam-log-analyzer | 异常区间时间戳（用于定位对应日志） |
| slam-debug-helper | 误差时序和异常区间（用于根因诊断） |
| slam-perf-optimizer | 完整评估结果（用于迭代对比） |

### 错误处理

当 spec 文件缺失时：

```
⚠️ 无法执行 slam-eval-runner

原因: 缺少项目规格文件:
  - {project}/.specs/project-spec.md

解决方案:
  先执行 slam-project-profiler 生成项目规格

是否需要我帮你执行 profiler？(Y/n)
```

当评估脚本执行失败时：

```
⚠️ 评估脚本执行失败

命令: {command}
退出码: {exit_code}
错误输出:
{stderr}

请检查:
1. 评估脚本路径是否正确
2. 轨迹文件和真值文件是否存在
3. 脚本是否有执行权限
```
