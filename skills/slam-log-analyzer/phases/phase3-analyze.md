# Phase 3: 时段分析

## 目标

分析指定时间段内的日志，结合评估数据，识别异常模式和关键事件。

## 输入

- `log-index.json`: Phase 1 的日志索引
- `code-log-mapping.json`: Phase 2 的代码映射
- `time_range`: 分析的时间范围（可选，默认分析整个日志）
- `eval-results.json`: eval-runner 的评估结果（可选）

## 输出

- `time-range-analysis.json`: 时段分析结果
- `analysis-report.md`: 人类可读的分析报告

## 执行步骤

### Step 1: 确定分析时间段

#### 1.1 用户指定时间段
如果用户指定了时间段（如 "10-20秒"），解析时间范围：

```python
def parse_time_range(time_range_str):
    """
    解析时间范围字符串
    支持格式: "10-20", "10.5-20.5", "start:10 end:20"
    """
    import re
    
    # 简单格式: "10-20"
    match = re.match(r'(\d+\.?\d*)\s*-\s*(\d+\.?\d*)', time_range_str)
    if match:
        return float(match.group(1)), float(match.group(2))
    
    # 命名格式: "start:10 end:20"
    start_match = re.search(r'start[:\s]+(\d+\.?\d*)', time_range_str)
    end_match = re.search(r'end[:\s]+(\d+\.?\d*)', time_range_str)
    if start_match and end_match:
        return float(start_match.group(1)), float(end_match.group(1))
    
    raise ValueError(f"无法解析时间范围: {time_range_str}")
```

#### 1.2 从评估结果获取异常时间段
如果有 eval-runner 的结果，提取异常时间段：

```python
def get_anomaly_periods(eval_results):
    """
    从评估结果中提取异常时间段
    """
    anomaly_periods = []
    
    # 从误差时序中提取异常区间
    if 'error_timeseries' in eval_results:
        timeseries = eval_results['error_timeseries']
        mean_error = sum(t['error'] for t in timeseries) / len(timeseries)
        threshold = mean_error * 2  # 2倍平均误差
        
        current_period = None
        for point in timeseries:
            if point['error'] > threshold:
                if current_period is None:
                    current_period = {
                        'start': point['timestamp'],
                        'end': point['timestamp'],
                        'max_error': point['error']
                    }
                else:
                    current_period['end'] = point['timestamp']
                    current_period['max_error'] = max(current_period['max_error'], point['error'])
            else:
                if current_period is not None:
                    # 检查是否与上一个区间连续（间隔<1秒）
                    if point['timestamp'] - current_period['end'] < 1.0:
                        current_period['end'] = point['timestamp']
                    else:
                        anomaly_periods.append(current_period)
                        current_period = None
        
        if current_period is not None:
            anomaly_periods.append(current_period)
    
    return anomaly_periods
```

### Step 2: 提取时间段内的日志

```python
def extract_logs_in_range(log_index, start_time, end_time):
    """
    提取指定时间段内的日志
    """
    logs_in_range = []
    
    for entry in log_index['entries']:
        if start_time <= entry['timestamp'] <= end_time:
            logs_in_range.append(entry)
    
    return logs_in_range
```

### Step 3: 统计关键指标

分析时间段内的关键指标变化：

```python
def analyze_key_metrics(logs_in_range):
    """
    分析关键指标
    """
    metrics = {
        'feature_count': [],
        'inlier_count': [],
        'outlier_count': [],
        'optimization_iterations': [],
        'optimization_cost': [],
        'processing_time_ms': [],
        'fps': []
    }
    
    for entry in logs_in_range:
        # 提取特征信息
        if 'extracted_info' in entry:
            info = entry['extracted_info']
            if 'feature_count' in info:
                metrics['feature_count'].append({
                    'timestamp': entry['timestamp'],
                    'value': info['feature_count']
                })
            if 'inlier_count' in info:
                metrics['inlier_count'].append({
                    'timestamp': entry['timestamp'],
                    'value': info['inlier_count']
                })
            if 'outlier_count' in info:
                metrics['outlier_count'].append({
                    'timestamp': entry['timestamp'],
                    'value': info['outlier_count']
                })
            if 'iterations' in info:
                metrics['optimization_iterations'].append({
                    'timestamp': entry['timestamp'],
                    'value': info['iterations']
                })
            if 'cost' in info:
                metrics['optimization_cost'].append({
                    'timestamp': entry['timestamp'],
                    'value': info['cost']
                })
            if 'time_ms' in info:
                metrics['processing_time_ms'].append({
                    'timestamp': entry['timestamp'],
                    'value': info['time_ms']
                })
            if 'fps' in info:
                metrics['fps'].append({
                    'timestamp': entry['timestamp'],
                    'value': info['fps']
                })
    
    # 计算统计量
    import numpy as np
    
    stats = {}
    for key, values in metrics.items():
        if values:
            vals = [v['value'] for v in values]
            stats[key] = {
                'mean': np.mean(vals),
                'std': np.std(vals),
                'min': np.min(vals),
                'max': np.max(vals),
                'count': len(vals),
                'values': values
            }
    
    return stats
```

### Step 4: 识别关键事件

识别时间段内的关键事件：

```python
def identify_key_events(logs_in_range):
    """
    识别关键事件
    """
    events = []
    
    # 错误和警告
    for entry in logs_in_range:
        if entry['level'] in ['ERROR', 'WARN']:
            events.append({
                'timestamp': entry['timestamp'],
                'type': entry['level'],
                'module': entry.get('module', 'unknown'),
                'message': entry['message'],
                'severity': 'high' if entry['level'] == 'ERROR' else 'medium'
            })
    
    # 系统状态变化
    state_changes = [
        ('初始化', r'initializ(ed|ing)|started|launched'),
        ('关闭', r'shutdown|stopped|terminated|exited'),
        ('回环检测', r'loop.*detect|closure'),
        ('重定位', r'relocali[sz]ation|recovery'),
        ('地图保存', r'sav(e|ing).*map'),
        ('地图加载', r'load(e|ing).*map')
    ]
    
    for entry in logs_in_range:
        for event_name, pattern in state_changes:
            if re.search(pattern, entry['message'], re.IGNORECASE):
                events.append({
                    'timestamp': entry['timestamp'],
                    'type': event_name,
                    'module': entry.get('module', 'unknown'),
                    'message': entry['message'],
                    'severity': 'low'
                })
    
    # 性能异常
    for entry in logs_in_range:
        if 'extracted_info' in entry:
            info = entry['extracted_info']
            
            # 特征数骤降
            if 'feature_count' in info and info['feature_count'] < 50:
                events.append({
                    'timestamp': entry['timestamp'],
                    'type': '特征数骤降',
                    'module': entry.get('module', 'unknown'),
                    'message': f"特征数: {info['feature_count']}",
                    'severity': 'high'
                })
            
            # 优化失败
            if 'iterations' in info and info['iterations'] > 20:
                events.append({
                    'timestamp': entry['timestamp'],
                    'type': '优化迭代过多',
                    'module': entry.get('module', 'unknown'),
                    'message': f"迭代次数: {info['iterations']}",
                    'severity': 'medium'
                })
    
    # 按时间排序
    events.sort(key=lambda x: x['timestamp'])
    
    return events
```

### Step 5: 关联代码位置

将关键事件关联到代码位置：

```python
def correlate_events_to_code(events, code_log_mapping):
    """
    将事件关联到代码位置
    """
    for event in events:
        # 查找匹配的日志模式
        for mapping in code_log_mapping['mappings']:
            pattern = mapping['log_pattern']
            # 将模式转换为正则
            regex_pattern = pattern.replace('<NUM>', r'\d+')
            regex_pattern = regex_pattern.replace('<FLOAT>', r'[\d.]+')
            
            if re.search(regex_pattern, event['message']):
                event['code_location'] = mapping['code_location']
                break
    
    return events
```

### Step 6: 生成分析报告

#### 6.1 输出 time-range-analysis.json

```json
{
  "version": "1.0",
  "time_range": {
    "start": 1623456789.123,
    "end": 1623456799.456,
    "duration": 10.333
  },
  "log_count": 150,
  "key_metrics": {
    "feature_count": {
      "mean": 145.5,
      "std": 15.2,
      "min": 100,
      "max": 180,
      "values": [...]
    },
    "inlier_count": {
      "mean": 130.2,
      "std": 12.5,
      "min": 90,
      "max": 160,
      "values": [...]
    }
  },
  "key_events": [
    {
      "timestamp": 1623456790.123,
      "type": "ERROR",
      "module": "tracker",
      "message": "Tracking failed: not enough inliers",
      "severity": "high",
      "code_location": {
        "file": "src/tracker.cpp",
        "line": 456,
        "function": "trackFeatures"
      }
    }
  ],
  "anomaly_patterns": [
    {
      "pattern": "特征数持续下降",
      "start_time": 1623456795.0,
      "end_time": 1623456799.0,
      "description": "特征数从 150 下降到 80"
    }
  ]
}
```

#### 6.2 输出 analysis-report.md

```markdown
# 日志时段分析报告

## 基本信息

- **时间范围**: 1623456789.123 - 1623456799.456 (10.3 秒)
- **日志条目数**: 150
- **分析模块**: tracker, optimizer, viewer

## 关键指标统计

### 特征跟踪
- **特征数**: 平均 145.5 ± 15.2 (范围: 100-180)
- **内点数**: 平均 130.2 ± 12.5 (范围: 90-160)
- **外点数**: 平均 15.3 ± 5.2 (范围: 10-25)

### 优化性能
- **迭代次数**: 平均 5.3 ± 1.2 (范围: 3-10)
- **优化代价**: 平均 0.012 ± 0.003

### 处理性能
- **处理时间**: 平均 33.5 ± 2.1 ms (范围: 30-40 ms)
- **帧率**: 平均 29.8 ± 1.5 FPS (范围: 25-33 FPS)

## 关键事件

### 高严重度事件

| 时间 | 模块 | 事件 | 代码位置 |
|------|------|------|---------|
| 1623456790.123 | tracker | Tracking failed: not enough inliers | tracker.cpp:456 |
| 1623456795.456 | optimizer | Optimization diverged | optimizer.cpp:789 |

### 中等严重度事件

| 时间 | 模块 | 事件 | 代码位置 |
|------|------|------|---------|
| 1623456792.789 | tracker | 优化迭代过多 (25次) | tracker.cpp:234 |

## 异常模式

### 模式 1: 特征数持续下降
- **时间**: 1623456795.0 - 1623456799.0
- **描述**: 特征数从 150 下降到 80
- **可能原因**: 
  - 场景纹理不足
  - 相机运动过快
  - 曝光问题

### 模式 2: 优化不稳定
- **时间**: 1623456790.0 - 1623456795.0
- **描述**: 优化迭代次数波动大 (3-25次)
- **可能原因**:
  - 初始值不佳
  - 噪声参数不合理
  - 外参误差大

## 建议

### 立即行动
1. 检查 tracker.cpp:456 处的跟踪失败原因
2. 检查 optimizer.cpp:789 处的优化发散原因

### 进一步分析
1. 分析特征数下降时的图像质量
2. 检查优化参数设置
3. 对比正常时段的日志模式

### 代码插桩建议
1. 在 tracker.cpp:456 附近添加更多调试日志
2. 在 optimizer.cpp:789 附近记录优化过程
```

### Step 7: 用户交互

向用户展示分析结果：

```
✅ 时段分析完成

📊 分析概览:
- 时间范围: 10.3 秒
- 日志条目: 150 条
- 关键事件: 5 个 (2 个高严重度)

🔴 高严重度事件:
1. [1623456790.123] tracker: Tracking failed (tracker.cpp:456)
2. [1623456795.456] optimizer: Optimization diverged (optimizer.cpp:789)

📈 异常模式:
1. 特征数持续下降 (150 → 80)
2. 优化不稳定 (迭代 3-25 次)

💡 建议:
1. 检查 tracker.cpp:456 的跟踪失败原因
2. 检查 optimizer.cpp:789 的优化发散原因
3. 添加调试日志进一步分析

是否查看某个事件的详细代码？(输入事件编号)
是否添加调试日志？(Y/n)
```

## 高级功能

### 对比分析

对比正常时段和异常时段的日志模式：

```python
def compare_periods(normal_logs, anomaly_logs):
    """
    对比正常和异常时段
    """
    normal_metrics = analyze_key_metrics(normal_logs)
    anomaly_metrics = analyze_key_metrics(anomaly_logs)
    
    comparison = {}
    for key in normal_metrics:
        if key in anomaly_metrics:
            normal_mean = normal_metrics[key]['mean']
            anomaly_mean = anomaly_metrics[key]['mean']
            diff = anomaly_mean - normal_mean
            diff_percent = (diff / normal_mean * 100) if normal_mean != 0 else 0
            
            comparison[key] = {
                'normal': normal_mean,
                'anomaly': anomaly_mean,
                'diff': diff,
                'diff_percent': diff_percent
            }
    
    return comparison
```

### 时序可视化

生成时序图表：

```python
def generate_timeline_chart(metrics, output_file):
    """
    生成时序图表
    """
    import matplotlib.pyplot as plt
    
    fig, axes = plt.subplots(3, 1, figsize=(12, 8))
    
    # 特征数
    if 'feature_count' in metrics:
        timestamps = [v['timestamp'] for v in metrics['feature_count']['values']]
        values = [v['value'] for v in metrics['feature_count']['values']]
        axes[0].plot(timestamps, values)
        axes[0].set_ylabel('Feature Count')
    
    # 内点数
    if 'inlier_count' in metrics:
        timestamps = [v['timestamp'] for v in metrics['inlier_count']['values']]
        values = [v['value'] for v in metrics['inlier_count']['values']]
        axes[1].plot(timestamps, values)
        axes[1].set_ylabel('Inlier Count')
    
    # 处理时间
    if 'processing_time_ms' in metrics:
        timestamps = [v['timestamp'] for v in metrics['processing_time_ms']['values']]
        values = [v['value'] for v in metrics['processing_time_ms']['values']]
        axes[2].plot(timestamps, values)
        axes[2].set_ylabel('Processing Time (ms)')
    
    plt.tight_layout()
    plt.savefig(output_file)
```

## 错误处理

### 错误 1: 时间段内无日志
```
❌ 指定时间段内无日志

时间范围: 10.0 - 20.0 秒
日志时间范围: 0.0 - 5.0 秒

解决方案:
1. 检查时间范围是否正确
2. 检查日志文件是否完整
3. 选择其他时间段
```

### 错误 2: 无法提取关键指标
```
⚠️ 无法提取关键指标

该时间段内的日志不包含关键指标信息（特征数、迭代次数等）。

可能原因:
1. 日志级别不够详细（只有 INFO，没有 DEBUG）
2. 日志格式不包含结构化信息

建议:
1. 提高日志级别（DEBUG）
2. 添加结构化日志输出
```

## 注意事项

1. **时间戳精度**: 保留完整精度，避免四舍五入
2. **大时段处理**: 如果时间段 > 1 分钟，考虑分段分析
3. **日志密度**: 注意日志密度变化（突然增多或减少）
4. **时区问题**: 确保所有时间戳使用相同时区
5. **性能考虑**: 大时段分析时使用流式处理，避免内存溢出
