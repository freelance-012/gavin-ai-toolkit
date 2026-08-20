# Phase 1: 日志解析

## 目标

解析日志文件，提取结构化信息，建立时间索引，为后续分析做准备。

## 输入

- `log-scan-report.json`: Phase 0 的扫描结果
- `project_path`: 项目根目录

## 输出

- `log-index.json`: 日志索引，包含所有日志条目的结构化信息
- `log-stats.json`: 日志统计信息

## 执行步骤

### Step 1: 加载扫描结果

读取 `log-scan-report.json`，获取：
- 日志文件路径
- 日志格式（ros / custom / plain）
- 时间戳格式（unix / datetime / relative）

### Step 2: 解析日志条目

根据日志格式，逐行解析日志：

#### 2.1 ROS 日志解析

```python
import re

ros_pattern = r'^\[(INFO|WARN|ERROR|DEBUG|FATAL)\] \[([\d.]+)\]: \[(\w+)\] (.*)$'

def parse_ros_log(line):
    match = re.match(ros_pattern, line)
    if match:
        return {
            'level': match.group(1),
            'timestamp': float(match.group(2)),
            'module': match.group(3),
            'message': match.group(4),
            'raw': line
        }
    return None
```

#### 2.2 自定义格式解析

```python
custom_pattern = r'^\[([\d-]+ [\d:.]+)\] \[(\w+)\] \[(\w+)\] (\w+\.cpp:\d+) - (.*)$'

def parse_custom_log(line):
    match = re.match(custom_pattern, line)
    if match:
        from datetime import datetime
        dt = datetime.strptime(match.group(1), '%Y-%m-%d %H:%M:%S.%f')
        timestamp = dt.timestamp()
        
        return {
            'level': match.group(2),
            'timestamp': timestamp,
            'module': match.group(3),
            'location': match.group(4),  # file.cpp:line
            'message': match.group(5),
            'raw': line
        }
    return None
```

#### 2.3 纯文本格式解析

```python
plain_pattern = r'^([\d.]+) (\w+) (.*)$'

def parse_plain_log(line):
    match = re.match(plain_pattern, line)
    if match:
        return {
            'timestamp': float(match.group(1)),
            'level': match.group(2),
            'message': match.group(3),
            'raw': line
        }
    return None
```

### Step 3: 提取关键信息

从日志消息中提取关键信息（使用正则表达式）：

#### 3.1 特征跟踪信息
```python
feature_patterns = [
    r'Tracked (\d+) features',
    r'Features: (\d+)',
    r'(\d+) keypoints',
    r'Inliers: (\d+)',
    r'Outliers: (\d+)'
]

def extract_feature_info(message):
    info = {}
    for pattern in feature_patterns:
        match = re.search(pattern, message)
        if match:
            if 'features' in pattern.lower() or 'keypoints' in pattern.lower():
                info['feature_count'] = int(match.group(1))
            elif 'inliers' in pattern.lower():
                info['inlier_count'] = int(match.group(1))
            elif 'outliers' in pattern.lower():
                info['outlier_count'] = int(match.group(1))
    return info
```

#### 3.2 优化信息
```python
optimization_patterns = [
    r'converged in (\d+) iterations',
    r'cost: ([\d.]+)',
    r'error: ([\d.]+)',
    r'iterations: (\d+)'
]

def extract_optimization_info(message):
    info = {}
    for pattern in optimization_patterns:
        match = re.search(pattern, message)
        if match:
            if 'iterations' in pattern:
                info['iterations'] = int(match.group(1))
            elif 'cost' in pattern or 'error' in pattern:
                info['cost'] = float(match.group(1))
    return info
```

#### 3.3 时间信息
```python
timing_patterns = [
    r'Time: ([\d.]+) ms',
    r'Processing time: ([\d.]+) s',
    r'(\d+) Hz',
    r'FPS: ([\d.]+)'
]

def extract_timing_info(message):
    info = {}
    for pattern in timing_patterns:
        match = re.search(pattern, message)
        if match:
            if 'ms' in pattern:
                info['time_ms'] = float(match.group(1))
            elif 'Hz' in pattern:
                info['frequency'] = float(match.group(1))
            elif 'FPS' in pattern:
                info['fps'] = float(match.group(1))
    return info
```

### Step 4: 建立时间索引

创建时间索引，支持快速查询：

```python
time_index = {}

for entry in log_entries:
    ts = entry['timestamp']
    
    # 按秒索引
    ts_sec = int(ts)
    if ts_sec not in time_index:
        time_index[ts_sec] = []
    time_index[ts_sec].append(entry)

# 排序每个时间点的日志
for ts_sec in time_index:
    time_index[ts_sec].sort(key=lambda x: x['timestamp'])
```

### Step 5: 生成统计信息

统计日志的整体信息：

```python
stats = {
    'total_entries': len(log_entries),
    'time_range': {
        'start': min(e['timestamp'] for e in log_entries),
        'end': max(e['timestamp'] for e in log_entries),
        'duration': max(e['timestamp'] for e in log_entries) - min(e['timestamp'] for e in log_entries)
    },
    'level_distribution': {},
    'module_distribution': {},
    'feature_stats': {
        'count': [],
        'inliers': [],
        'outliers': []
    },
    'optimization_stats': {
        'iterations': [],
        'cost': []
    },
    'timing_stats': {
        'time_ms': [],
        'fps': []
    }
}

# 统计各级别日志数量
for entry in log_entries:
    level = entry.get('level', 'UNKNOWN')
    stats['level_distribution'][level] = stats['level_distribution'].get(level, 0) + 1
    
    module = entry.get('module', 'unknown')
    stats['module_distribution'][module] = stats['module_distribution'].get(module, 0) + 1
    
    # 提取关键信息
    feature_info = extract_feature_info(entry['message'])
    if 'feature_count' in feature_info:
        stats['feature_stats']['count'].append(feature_info['feature_count'])
    if 'inlier_count' in feature_info:
        stats['feature_stats']['inliers'].append(feature_info['inlier_count'])
    if 'outlier_count' in feature_info:
        stats['feature_stats']['outliers'].append(feature_info['outlier_count'])
    
    opt_info = extract_optimization_info(entry['message'])
    if 'iterations' in opt_info:
        stats['optimization_stats']['iterations'].append(opt_info['iterations'])
    if 'cost' in opt_info:
        stats['optimization_stats']['cost'].append(opt_info['cost'])
    
    timing_info = extract_timing_info(entry['message'])
    if 'time_ms' in timing_info:
        stats['timing_stats']['time_ms'].append(timing_info['time_ms'])
    if 'fps' in timing_info:
        stats['timing_stats']['fps'].append(timing_info['fps'])

# 计算统计量
import numpy as np

for key in ['count', 'inliers', 'outliers']:
    if stats['feature_stats'][key]:
        arr = stats['feature_stats'][key]
        stats['feature_stats'][f'{key}_mean'] = np.mean(arr)
        stats['feature_stats'][f'{key}_std'] = np.std(arr)
        stats['feature_stats'][f'{key}_min'] = np.min(arr)
        stats['feature_stats'][f'{key}_max'] = np.max(arr)

# 类似处理 optimization_stats 和 timing_stats
```

### Step 6: 输出结果

#### 6.1 输出 log-index.json

```json
{
  "version": "1.0",
  "log_file": "/path/to/log.txt",
  "log_format": "ros",
  "total_entries": 15000,
  "entries": [
    {
      "line_number": 1,
      "timestamp": 1623456789.123456,
      "level": "INFO",
      "module": "tracker",
      "message": "Tracked 150 features",
      "extracted_info": {
        "feature_count": 150
      },
      "raw": "[INFO] [1623456789.123456]: [tracker] Tracked 150 features"
    }
  ],
  "time_index": {
    "1623456789": [0, 1, 2, 3],
    "1623456790": [4, 5, 6, 7]
  }
}
```

#### 6.2 输出 log-stats.json

```json
{
  "version": "1.0",
  "total_entries": 15000,
  "time_range": {
    "start": 1623456789.123,
    "end": 1623457089.456,
    "duration": 300.333
  },
  "level_distribution": {
    "INFO": 12000,
    "DEBUG": 2500,
    "WARN": 400,
    "ERROR": 100
  },
  "module_distribution": {
    "tracker": 5000,
    "optimizer": 4000,
    "viewer": 3000,
    "system": 3000
  },
  "feature_stats": {
    "count": [150, 148, 152, ...],
    "count_mean": 149.5,
    "count_std": 5.2,
    "count_min": 120,
    "count_max": 180,
    "inliers": [130, 128, 132, ...],
    "inliers_mean": 129.5,
    "outliers": [20, 20, 20, ...]
  },
  "optimization_stats": {
    "iterations": [5, 6, 5, ...],
    "iterations_mean": 5.3,
    "cost": [0.012, 0.011, 0.013, ...],
    "cost_mean": 0.012
  },
  "timing_stats": {
    "time_ms": [33.5, 34.2, 32.8, ...],
    "time_ms_mean": 33.5,
    "fps": [29.8, 29.3, 30.2, ...],
    "fps_mean": 29.8
  }
}
```

### Step 7: 用户反馈

向用户展示解析结果：

```
✅ 日志解析完成

📊 统计信息:
- 总条目数: 15000
- 时间范围: 300.3 秒
- 日志级别: INFO 12000, DEBUG 2500, WARN 400, ERROR 100
- 模块分布: tracker 5000, optimizer 4000, viewer 3000, system 3000

📈 关键指标:
- 特征数: 平均 149.5 ± 5.2 (范围: 120-180)
- 内点数: 平均 129.5
- 优化迭代: 平均 5.3 次
- 处理时间: 平均 33.5 ms (29.8 FPS)

🔍 异常检测:
- ERROR 日志: 100 条
- 特征数异常 (<100): 5 次
- 优化失败 (迭代>20): 3 次

是否继续分析特定时间段？(Y/n)
```

## 性能优化

### 大文件处理

如果日志文件 > 100MB：

1. **分块读取**
   ```python
   chunk_size = 10000  # 每次读取 10000 行
   for chunk in read_in_chunks(file, chunk_size):
       process_chunk(chunk)
   ```

2. **并行解析**
   ```python
   from multiprocessing import Pool
   
   with Pool(4) as p:
       entries = p.map(parse_log_line, lines)
   ```

3. **内存优化**
   - 只保留必要的字段
   - 使用生成器而非列表
   - 定期清理临时数据

### 进度显示

```python
from tqdm import tqdm

for line in tqdm(file, desc="解析日志", total=total_lines):
    parse_log_line(line)
```

## 错误处理

### 错误 1: 日志格式不一致
```
⚠️ 发现日志格式不一致

第 1234 行: 无法解析
```
[INFO] [1623456789.123]: [tracker] Tracked 150 features
```

第 5678 行: 格式不同
```
1623456789.456 INFO Tracked 150 features
```

解决方案:
1. 跳过无法解析的行
2. 使用多种解析器尝试
3. 手动指定格式
```

### 错误 2: 时间戳异常
```
⚠️ 发现时间戳异常

第 1234 行: 时间戳跳变
- 前一条: 1623456789.123
- 当前: 1623456000.000 (跳变 -789 秒)

可能原因:
1. 系统时间调整
2. 日志文件拼接
3. 时间戳格式错误

是否继续？(Y/n)
```

## 注意事项

1. **内存占用**: 大文件解析时注意内存使用
2. **编码问题**: 统一使用 UTF-8 编码
3. **时区问题**: 注意时间戳的时区（UTC / 本地时间）
4. **精度问题**: 保留时间戳的完整精度（不四舍五入）
5. **特殊字符**: 处理日志中的特殊字符（换行、制表符等）
