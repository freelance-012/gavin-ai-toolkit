# Phase 2: 时序分析

## 目标

对误差时序数据进行分析，生成误差曲线，标注误差异常的时间区间，为后续日志分析和根因诊断提供定位依据。

## 触发词

- "分析误差时序"
- "标注异常区间"

## 依赖

Phase 1 产出的 `error-timeseries.csv`

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| timeseries_file | string | ✅ | 误差时序数据文件路径 |
| output_dir | string | ✅ | 分析结果输出目录 |

## 输出产物

```
{output_dir}/
├── error-timeseries.csv         # 原始时序数据（从 Phase 1 复制）
├── anomaly-intervals.json       # 异常区间列表
├── error-stats.json             # 统计信息
└── error-plot.png               # 误差时序图（如果能生成）
```

## 执行步骤

### Step 0: 检查时序数据

检查 `error-timeseries.csv` 是否存在。

如果不存在（Phase 1 标注"评估脚本未提供时序数据"）：

```
⚠️ 无法进行时序分析

原因: 评估脚本未输出误差时序数据

解决方案:
  1. 修改评估脚本，增加逐帧误差输出
  2. 或者使用其他支持时序输出的评估工具

是否跳过时序分析，直接进入报告阶段？(Y/n)
```

### Step 1: 基础统计

从时序数据计算统计信息：

```python
# 伪代码
import numpy as np

errors = load_csv(timeseries_file)

stats = {
    "total_frames": len(errors),
    "time_range": [errors[0].timestamp, errors[-1].timestamp],
    "duration": errors[-1].timestamp - errors[0].timestamp,
    "error_mean": np.mean(errors.error),
    "error_median": np.median(errors.error),
    "error_std": np.std(errors.error),
    "error_min": np.min(errors.error),
    "error_max": np.max(errors.error),
    "error_rmse": np.sqrt(np.mean(errors.error**2)),
    # 分位数
    "error_p90": np.percentile(errors.error, 90),
    "error_p95": np.percentile(errors.error, 95),
    "error_p99": np.percentile(errors.error, 99),
}
```

输出统计摘要：

```
📊 **误差统计**

| 指标 | 值 |
|------|-----|
| 总帧数 | {N} |
| 时间范围 | {t_start} ~ {t_end} ({duration}s) |
| 平均误差 | {mean} {unit} |
| 中位数误差 | {median} {unit} |
| 标准差 | {std} {unit} |
| 最大误差 | {max} {unit} |
| RMSE | {rmse} {unit} |
| P90 | {p90} {unit} |
| P95 | {p95} {unit} |
| P99 | {p99} {unit} |
```

### Step 2: 异常区间检测

**判定标准**（按优先级）：

1. **用户指定阈值**：如果 spec 中定义了合格阈值，使用该阈值
2. **统计阈值**：误差 > mean + 2*std
3. **百分位阈值**：误差 > P95

**检测算法**：

```
1. 计算阈值 threshold
2. 标记所有 error > threshold 的帧为"异常帧"
3. 将连续异常帧合并为区间
4. 过滤掉持续时间 < min_duration（默认 0.5 秒）的区间
5. 合并间隔 < gap_threshold（默认 1.0 秒）的相邻区间
```

**输出格式**（`anomaly-intervals.json`）：

```json
{
  "threshold": 0.1,
  "threshold_source": "mean + 2*std",
  "intervals": [
    {
      "id": 1,
      "start_time": 1623456790.123,
      "end_time": 1623456792.456,
      "duration": 2.333,
      "frames": 234,
      "max_error": 0.234,
      "mean_error": 0.156,
      "severity": "high"
    },
    ...
  ],
  "total_anomaly_duration": 5.678,
  "total_duration": 120.0,
  "anomaly_ratio": 0.047
}
```

**严重程度分级**：
- `high`：max_error > 3 * threshold
- `medium`：max_error > 2 * threshold
- `low`：max_error > threshold

### Step 3: 滑动窗口分析

为了更细致地展示误差变化趋势，计算滑动窗口统计：

```
窗口大小: 1 秒（或 100 帧，取较小者）
步长: 0.1 秒（或 10 帧）

对每个窗口计算:
- 窗口内平均误差
- 窗口内最大误差
- 窗口内误差标准差
```

### Step 4: 生成误差曲线图（可选）

如果环境支持（matplotlib 可用），生成误差时序图：

```python
# 伪代码
import matplotlib.pyplot as plt

fig, axes = plt.subplots(3, 1, figsize=(12, 8), sharex=True)

# 子图1: 原始误差 + 阈值线
axes[0].plot(timestamps, errors, label='Error')
axes[0].axhline(threshold, color='r', linestyle='--', label='Threshold')
for interval in anomaly_intervals:
    axes[0].axvspan(interval.start, interval.end, alpha=0.3, color='red')
axes[0].set_ylabel('Error')
axes[0].legend()

# 子图2: 滑动窗口平均
axes[1].plot(window_timestamps, window_mean, label='Mean (1s window)')
axes[1].set_ylabel('Mean Error')

# 子图3: 各分量误差（如果有）
if has_components:
    axes[2].plot(timestamps, error_x, label='X')
    axes[2].plot(timestamps, error_y, label='Y')
    axes[2].plot(timestamps, error_z, label='Z')
    axes[2].set_ylabel('Component Error')
    axes[2].legend()

plt.xlabel('Time (s)')
plt.savefig('{output_dir}/error-plot.png', dpi=150, bbox_inches='tight')
```

### Step 5: 汇总异常区间

```markdown
🔍 **异常区间检测结果**

### 检测参数
- 阈值: {threshold} {unit}（{threshold_source}）
- 最小持续时间: {min_duration}s
- 合并间隔: {gap_threshold}s

### 异常区间列表

| # | 时间区间 | 持续时间 | 帧数 | 最大误差 | 平均误差 | 严重程度 |
|---|---------|---------|------|---------|---------|---------|
| 1 | {start} ~ {end} | {dur}s | {N} | {max} | {mean} | 🔴 高 / 🟡 中 / 🟢 低 |
| ... | ... | ... | ... | ... | ... | ... |

### 统计
- 异常区间数: {N}
- 异常总时长: {total_anomaly}s / {total_duration}s ({ratio}%)
- 最严重区间: #{id}（{start} ~ {end}，max={max}）

### 后续分析建议
可以使用以下命令分析异常区间对应的日志:
  "分析 {start} ~ {end} 时间段的日志"
```

## 注意事项

1. **时间戳单位**：注意时间戳的单位（秒/毫秒/纳秒），统一转换为秒进行分析
2. **缺失值处理**：如果时序数据中有缺失帧，需要插值或跳过
3. **多指标支持**：如果时序数据包含多个误差分量（x/y/z 或 translation/rotation），分别分析
4. **大数据集**：如果帧数 > 100000，使用采样或分块处理避免内存溢出
