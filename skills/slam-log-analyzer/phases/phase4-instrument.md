# Phase 4: 插桩设计

## 目标

基于日志分析结果，设计并添加调试日志（代码插桩），帮助深入理解系统行为。

## 输入

- `time-range-analysis.json`: Phase 3 的时段分析结果
- `code-log-mapping.json`: Phase 2 的代码映射
- `project_path`: 项目根目录

## 输出

- `instrument-plan.json`: 插桩计划
- `instrument-patches/`: 代码补丁文件
- `instrument-report.md`: 插桩报告

## 执行步骤

### Step 1: 识别需要插桩的位置

基于分析结果，识别需要添加调试日志的位置：

```python
def identify_instrumentation_points(analysis_results, code_mapping):
    """
    识别需要插桩的位置
    """
    points = []
    
    # 1. 高严重度事件的代码位置
    for event in analysis_results['key_events']:
        if event['severity'] == 'high' and 'code_location' in event:
            points.append({
                'reason': f"高严重度事件: {event['type']}",
                'location': event['code_location'],
                'timestamp': event['timestamp'],
                'message': event['message'],
                'priority': 'high'
            })
    
    # 2. 异常模式相关的代码位置
    for pattern in analysis_results['anomaly_patterns']:
        # 查找与异常模式相关的日志
        related_logs = find_related_logs(pattern, analysis_results['logs'])
        for log in related_logs:
            if 'code_location' in log:
                points.append({
                    'reason': f"异常模式: {pattern['pattern']}",
                    'location': log['code_location'],
                    'timestamp': log['timestamp'],
                    'message': log['message'],
                    'priority': 'medium'
                })
    
    # 3. 关键函数（基于调用频率）
    function_call_counts = {}
    for entry in analysis_results['logs']:
        if 'code_location' in entry:
            func = entry['code_location'].get('function', 'unknown')
            function_call_counts[func] = function_call_counts.get(func, 0) + 1
    
    # 取调用最频繁的函数
    top_functions = sorted(function_call_counts.items(), key=lambda x: x[1], reverse=True)[:5]
    for func, count in top_functions:
        if count > 10:  # 只考虑调用次数 > 10 的函数
            points.append({
                'reason': f"高频调用函数: {func} ({count}次)",
                'location': find_function_location(func, code_mapping),
                'priority': 'low'
            })
    
    # 去重
    unique_points = []
    seen_locations = set()
    for point in points:
        loc_key = f"{point['location']['file']}:{point['location']['line']}"
        if loc_key not in seen_locations:
            unique_points.append(point)
            seen_locations.add(loc_key)
    
    return unique_points
```

### Step 2: 设计插桩内容

为每个插桩点设计具体的日志内容：

```python
def design_instrumentation_content(point, context):
    """
    设计插桩内容
    """
    location = point['location']
    
    # 读取代码上下文
    with open(location['file'], 'r') as f:
        lines = f.readlines()
    
    # 获取插桩位置的代码
    line_idx = location['line'] - 1
    current_line = lines[line_idx]
    
    # 提取函数上下文
    func_name = location.get('function', 'unknown')
    
    # 设计日志内容
    log_content = {
        'timestamp': True,  # 记录时间戳
        'function': func_name,
        'variables': [],  # 需要记录的变量
        'metrics': [],  # 需要记录的指标
        'custom': []  # 自定义信息
    }
    
    # 根据上下文自动推断需要记录的变量
    # 1. 函数参数
    params = extract_function_params(lines, line_idx)
    log_content['variables'].extend(params)
    
    # 2. 局部变量（基于代码分析）
    local_vars = extract_local_variables(lines, line_idx)
    log_content['variables'].extend(local_vars[:5])  # 最多5个
    
    # 3. 基于异常类型的特定指标
    if '特征数' in point['reason']:
        log_content['metrics'].extend(['feature_count', 'inlier_count', 'outlier_count'])
    elif '优化' in point['reason']:
        log_content['metrics'].extend(['iterations', 'cost', 'converged'])
    elif '跟踪' in point['reason']:
        log_content['metrics'].extend(['tracking_status', 'match_count'])
    
    return log_content
```

### Step 3: 生成代码补丁

生成实际的代码修改：

```python
def generate_code_patch(location, log_content, log_framework='auto'):
    """
    生成代码补丁
    """
    file_path = location['file']
    line_num = location['line']
    
    # 读取原始代码
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    # 检测日志框架
    if log_framework == 'auto':
        log_framework = detect_log_framework(file_path)
    
    # 生成日志语句
    indent = get_indentation(lines[line_num - 1])
    log_stmt = generate_log_statement(log_content, log_framework, indent)
    
    # 插入日志语句
    # 策略：在目标行之前插入
    new_lines = lines[:line_num] + [log_stmt + '\n'] + lines[line_num:]
    
    # 生成补丁
    patch = {
        'file': file_path,
        'original_lines': lines,
        'modified_lines': new_lines,
        'insertion_line': line_num,
        'log_statement': log_stmt
    }
    
    return patch

def detect_log_framework(file_path):
    """
    检测文件使用的日志框架
    """
    with open(file_path, 'r') as f:
        content = f.read()
    
    if 'ROS_INFO' in content or 'ROS_DEBUG' in content:
        return 'ros'
    elif 'LOG(INFO)' in content or 'LOG(DEBUG)' in content:
        return 'glog'
    elif 'spdlog::info' in content or 'spdlog::debug' in content:
        return 'spdlog'
    elif 'printf' in content or 'cout' in content:
        return 'stdio'
    else:
        return 'custom'

def generate_log_statement(log_content, framework, indent):
    """
    生成日志语句
    """
    # 构建日志消息
    parts = []
    
    # 时间戳（大多数框架自动添加）
    # parts.append(f"time={get_timestamp()}")
    
    # 函数名
    parts.append(f"func={log_content['function']}")
    
    # 变量
    for var in log_content['variables']:
        parts.append(f"{var}={{{var}}}")
    
    # 指标
    for metric in log_content['metrics']:
        parts.append(f"{metric}={{{metric}}}")
    
    message = ' '.join(parts)
    
    # 根据框架生成语句
    if framework == 'ros':
        return f'{indent}ROS_DEBUG_STREAM("[DEBUG] {message}");'
    elif framework == 'glog':
        return f'{indent}LOG(INFO) << "[DEBUG] {message}";'
    elif framework == 'spdlog':
        return f'{indent}spdlog::debug("[DEBUG] {message}");'
    elif framework == 'stdio':
        return f'{indent}printf("[DEBUG] {message}\\n");'
    else:
        return f'{indent}// TODO: Add debug log: {message}'
```

### Step 4: 应用补丁

```python
def apply_patch(patch, dry_run=True):
    """
    应用补丁
    """
    file_path = patch['file']
    
    if dry_run:
        print(f"[DRY RUN] Would modify {file_path}")
        print(f"  Insert at line {patch['insertion_line']}:")
        print(f"  {patch['log_statement']}")
        return True
    
    # 备份原文件
    backup_path = f"{file_path}.bak"
    with open(backup_path, 'w') as f:
        f.writelines(patch['original_lines'])
    
    # 写入修改后的文件
    with open(file_path, 'w') as f:
        f.writelines(patch['modified_lines'])
    
    print(f"[APPLIED] Modified {file_path}")
    print(f"  Backup: {backup_path}")
    
    return True
```

### Step 5: 生成插桩计划

```python
def generate_instrument_plan(points, patches):
    """
    生成插桩计划
    """
    plan = {
        'version': '1.0',
        'total_points': len(points),
        'high_priority': sum(1 for p in points if p['priority'] == 'high'),
        'medium_priority': sum(1 for p in points if p['priority'] == 'medium'),
        'low_priority': sum(1 for p in points if p['priority'] == 'low'),
        'points': [],
        'patches': []
    }
    
    for i, point in enumerate(points):
        plan['points'].append({
            'id': i + 1,
            'reason': point['reason'],
            'location': point['location'],
            'priority': point['priority'],
            'patch_id': i + 1
        })
    
    for i, patch in enumerate(patches):
        plan['patches'].append({
            'id': i + 1,
            'file': patch['file'],
            'insertion_line': patch['insertion_line'],
            'log_statement': patch['log_statement']
        })
    
    return plan
```

### Step 6: 生成插桩报告

```markdown
# 代码插桩报告

## 概览

- **插桩点总数**: 15
- **高优先级**: 3
- **中优先级**: 7
- **低优先级**: 5

## 插桩点列表

### 高优先级

| ID | 原因 | 文件位置 | 代码行 |
|----|------|---------|--------|
| 1 | 高严重度事件: Tracking failed | src/tracker.cpp | 456 |
| 2 | 高严重度事件: Optimization diverged | src/optimizer.cpp | 789 |
| 3 | 异常模式: 特征数持续下降 | src/tracker.cpp | 234 |

### 中优先级

| ID | 原因 | 文件位置 | 代码行 |
|----|------|---------|--------|
| 4 | 异常模式: 优化不稳定 | src/optimizer.cpp | 567 |
| 5 | 异常模式: 内点比例低 | src/matcher.cpp | 123 |
| ... | ... | ... | ... |

### 低优先级

| ID | 原因 | 文件位置 | 代码行 |
|----|------|---------|--------|
| 10 | 高频调用函数: trackFeatures (150次) | src/tracker.cpp | 200 |
| 11 | 高频调用函数: optimize (150次) | src/optimizer.cpp | 500 |
| ... | ... | ... | ... |

## 代码补丁详情

### 补丁 1: tracker.cpp:456

**原因**: 高严重度事件: Tracking failed

**原始代码**:
```cpp
if (inlier_count < min_inliers) {
    return false;
}
```

**修改后代码**:
```cpp
ROS_DEBUG_STREAM("[DEBUG] func=trackFeatures feature_count={feature_count} inlier_count={inlier_count} outlier_count={outlier_count}");
if (inlier_count < min_inliers) {
    return false;
}
```

**说明**: 在跟踪失败前记录关键指标，帮助诊断失败原因。

### 补丁 2: optimizer.cpp:789

**原因**: 高严重度事件: Optimization diverged

**原始代码**:
```cpp
if (!converged) {
    LOG(ERROR) << "Optimization diverged";
    return false;
}
```

**修改后代码**:
```cpp
ROS_DEBUG_STREAM("[DEBUG] func=optimize iterations={iterations} cost={cost} converged={converged}");
if (!converged) {
    LOG(ERROR) << "Optimization diverged";
    return false;
}
```

**说明**: 在优化发散前记录优化过程，帮助诊断发散原因。

## 应用说明

### 应用所有补丁
```bash
# 使用 git apply
git apply instrument-patches/*.patch

# 或使用 patch 命令
patch -p1 < instrument-patches/patch_1.patch
```

### 撤销补丁
```bash
# 使用 git apply -R
git apply -R instrument-patches/*.patch

# 或恢复备份文件
cp src/tracker.cpp.bak src/tracker.cpp
```

### 注意事项

1. **日志级别**: 插桩使用 DEBUG 级别，生产环境请关闭
2. **性能影响**: 每个插桩点约增加 0.1ms 开销
3. **日志量**: 预计增加 10-20% 日志量
4. **清理**: 调试完成后请及时移除插桩代码

## 后续步骤

1. 应用补丁并重新编译
2. 运行系统并收集日志
3. 使用 slam-log-analyzer 分析新日志
4. 根据分析结果进一步插桩或修复问题
5. 调试完成后移除所有插桩代码
```

### Step 7: 用户交互

向用户展示插桩计划：

```
✅ 插桩计划生成完成

📊 插桩概览:
- 插桩点总数: 15
- 高优先级: 3 (关键问题点)
- 中优先级: 7 (异常模式相关)
- 低优先级: 5 (高频函数)

🔴 高优先级插桩点:
1. tracker.cpp:456 - Tracking failed
2. optimizer.cpp:789 - Optimization diverged
3. tracker.cpp:234 - 特征数持续下降

📝 代码补丁:
- 生成 15 个补丁文件
- 使用 ROS_DEBUG_STREAM 日志框架
- 预计增加 10-20% 日志量

💡 建议:
1. 先应用高优先级的 3 个补丁
2. 运行系统并收集日志
3. 分析新日志，进一步诊断

是否应用所有补丁？(Y/n)
是否只应用高优先级补丁？(y/N)
是否查看某个补丁的详情？(输入补丁ID)
```

## 高级功能

### 智能变量推断

基于代码上下文自动推断需要记录的变量：

```python
def smart_variable_inference(code_context):
    """
    智能推断需要记录的变量
    """
    variables = []
    
    # 1. 函数参数（总是记录）
    params = extract_function_params(code_context)
    variables.extend(params)
    
    # 2. 条件判断中的变量（关键决策点）
    conditions = extract_conditions(code_context)
    variables.extend(conditions)
    
    # 3. 循环计数器（性能相关）
    loop_counters = extract_loop_counters(code_context)
    variables.extend(loop_counters)
    
    # 4. 错误码和状态（问题诊断）
    error_codes = extract_error_codes(code_context)
    variables.extend(error_codes)
    
    # 5. 性能指标（时间、内存等）
    perf_metrics = extract_performance_metrics(code_context)
    variables.extend(perf_metrics)
    
    # 去重并限制数量
    unique_vars = list(dict.fromkeys(variables))
    return unique_vars[:10]  # 最多10个变量
```

### 条件插桩

只在特定条件下记录日志：

```cpp
// 只在跟踪失败时记录
if (tracking_failed) {
    ROS_DEBUG_STREAM("[DEBUG] func=trackFeatures feature_count=" << feature_count 
                     << " inlier_count=" << inlier_count);
}

// 只在优化迭代次数过多时记录
if (iterations > 20) {
    ROS_DEBUG_STREAM("[DEBUG] func=optimize iterations=" << iterations 
                     << " cost=" << cost);
}
```

### 采样插桩

降低日志频率，避免日志过多：

```cpp
// 每 10 帧记录一次
static int frame_count = 0;
if (++frame_count % 10 == 0) {
    ROS_DEBUG_STREAM("[DEBUG] func=trackFeatures feature_count=" << feature_count);
}

// 每秒钟记录一次
static auto last_log_time = std::chrono::steady_clock::now();
auto now = std::chrono::steady_clock::now();
if (std::chrono::duration_cast<std::chrono::seconds>(now - last_log_time).count() >= 1) {
    ROS_DEBUG_STREAM("[DEBUG] func=system fps=" << current_fps);
    last_log_time = now;
}
```

## 错误处理

### 错误 1: 无法修改文件
```
❌ 无法修改文件: src/tracker.cpp

原因: 文件只读或权限不足

解决方案:
1. 检查文件权限
2. 使用 sudo 或修改文件权限
3. 手动应用补丁
```

### 错误 2: 代码语法错误
```
❌ 生成的代码有语法错误

补丁 ID: 1
文件: src/tracker.cpp:456
错误: 未定义的变量 'feature_count'

解决方案:
1. 检查变量名是否正确
2. 检查变量作用域
3. 手动修正补丁
```

### 错误 3: 日志框架不匹配
```
⚠️ 日志框架不匹配

文件使用: glog
补丁使用: ros

解决方案:
1. 统一日志框架
2. 手动修改补丁
3. 使用通用日志（printf）
```

## 注意事项

1. **备份代码**: 应用补丁前自动备份原文件
2. **日志级别**: 使用 DEBUG 级别，避免影响生产环境
3. **性能影响**: 评估插桩对性能的影响
4. **日志量**: 控制日志量，避免磁盘空间不足
5. **清理**: 调试完成后及时移除插桩代码
6. **版本控制**: 不要将插桩代码提交到版本库
