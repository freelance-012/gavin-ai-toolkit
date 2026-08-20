# Phase 3: 生成报告

## 目标

汇总所有评估结果，生成结构化的评估报告，便于后续分析和对比。

## 触发词

- "生成评估报告"

## 依赖

Phase 1 的评估结果 + Phase 2 的时序分析结果

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| output_dir | string | ✅ | 评估结果目录 |

## 输出产物

```
{output_dir}/
└── eval-report.md              # 评估报告（套用模板）
```

同时更新软链接：

```bash
# 更新 latest 软链接指向当前结果目录
ln -sfn {output_dir} {project}/.specs/eval-results/latest
```

## 执行步骤

### Step 1: 读取所有结果

从 output_dir 中读取：
- `eval-stdout.txt`：评估脚本原始输出
- `error-stats.json`：误差统计信息（如果有）
- `anomaly-intervals.json`：异常区间列表（如果有）

### Step 2: 套用模板生成报告

读取 `templates/eval-report-template.md`，填充以下信息：

**必填信息**：
- 项目信息（名称、路径、代码版本）
- 评估时间
- 评估配置（脚本、轨迹、真值）
- 评估结果（各指标数值）

**可选信息**（如果 Phase 2 产出）：
- 误差统计摘要
- 异常区间列表
- 误差曲线图（如果有 PNG）

### Step 3: 对比历史结果（如果有）

检查 `{project}/.specs/eval-results/` 下是否有历史评估结果。

如果有，提取最近一次的历史结果进行对比：

```markdown
### 与上次评估对比

| 指标 | 上次 | 本次 | 变化 |
|------|------|------|------|
| ATE RMSE | 0.065 m | 0.052 m | -19.9% ✅ |
| ATE Max | 0.156 m | 0.123 m | -21.2% ✅ |
| 异常区间数 | 5 | 3 | -40.0% ✅ |
```

### Step 4: 写入报告

将生成的报告写入 `{output_dir}/eval-report.md`。

### Step 5: 展示最终结果

```markdown
✅ 评估完成

📁 结果目录: {output_dir}
📊 评估报告: {output_dir}/eval-report.md

### 关键指标
| 指标 | 值 | 状态 |
|------|-----|------|
| {metric1} | {value1} | ✅ 合格 / ❌ 不合格 |
| ... | ... | ... |

### 异常区间
共检测到 {N} 个异常区间，总异常时长 {duration}s（占比 {ratio}%）

### 后续建议
1. 分析异常区间对应的日志: "分析 {start} ~ {end} 时间段的日志"
2. 定位问题根因: "为什么 {start} ~ {end} 误差大"
3. 查看完整报告: 读取 {output_dir}/eval-report.md
```

## 注意事项

1. **报告格式**：严格套用 `eval-report-template.md` 模板
2. **历史记录**：保留所有历史评估结果，便于对比和回溯
3. **图表嵌入**：如果生成了 PNG 图表，在报告中用 Markdown 图片语法引用
4. **指标对比**：与历史结果对比时，标注变化趋势（改善/恶化）
