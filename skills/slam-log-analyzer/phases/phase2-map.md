# Phase 2: 代码映射

## 目标

建立日志消息与源代码位置的映射关系，支持从日志跳转到代码，从代码找到日志。

## 输入

- `log-index.json`: Phase 1 的日志索引
- `project_path`: 项目根目录

## 输出

- `code-log-mapping.json`: 代码-日志映射关系
- `log-coverage-report.json`: 映射覆盖率报告

## 执行步骤

### Step 1: 提取日志模式

从日志索引中提取唯一的日志消息模式：

```python
import re
from collections import Counter

# 提取消息模式（去除具体数值）
def extract_message_pattern(message):
    # 替换数字为 <NUM>
    pattern = re.sub(r'\b\d+\b', '<NUM>', message)
    # 替换浮点数为 <FLOAT>
    pattern = re.sub(r'\b\d+\.\d+\b', '<FLOAT>', pattern)
    # 替换文件路径为 <PATH>
    pattern = re.sub(r'/[\w/\.]+', '<PATH>', pattern)
    return pattern

# 统计所有消息模式
message_patterns = Counter()
for entry in log_entries:
    pattern = extract_message_pattern(entry['message'])
    message_patterns[pattern] += 1

# 取出现次数 > 1 的模式（重复出现的才有意义）
frequent_patterns = {p: c for p, c in message_patterns.items() if c > 1}
```

### Step 2: 搜索代码中的日志语句

在源代码中搜索日志输出语句：

#### 2.1 搜索常见日志宏/函数

```python
import os
import re

# 常见日志模式
log_patterns = [
    # ROS 日志
    r'ROS_(INFO|DEBUG|WARN|ERROR|FATAL)\s*\((.*?)\)',
    r'ROS_(INFO|DEBUG|WARN|ERROR|FATAL)_STREAM\s*\((.*?)\)',
    
    # C++ 日志
    r'LOG\((INFO|DEBUG|WARN|ERROR|FATAL)\)\s*<<\s*(.*?);',
    r'spdlog::(info|debug|warn|error|critical)\s*\((.*?)\)',
    r'glog::(INFO|DEBUG|WARN|ERROR|FATAL)\s*<<\s*(.*?);',
    
    # 自定义日志
    r'LOG_(INFO|DEBUG|WARN|ERROR|FATAL)\s*\((.*?)\)',
    r'print_log\((INFO|DEBUG|WARN|ERROR|FATAL),\s*(.*?)\)',
    
    # Python 日志
    r'logging\.(info|debug|warning|error|critical)\s*\((.*?)\)',
    r'logger\.(info|debug|warning|error|critical)\s*\((.*?)\)',
    
    # cout/cerr
    r'cout\s*<<\s*(.*?);',
    r'cerr\s*<<\s*(.*?);'
]

def find_log_statements(project_path):
    log_statements = []
    
    for root, dirs, files in os.walk(project_path):
        # 跳过第三方库和构建目录
        if any(skip in root for skip in ['build', 'third_party', 'external', '.git']):
            continue
        
        for file in files:
            if file.endswith(('.cpp', '.h', '.hpp', '.cc', '.c', '.py')):
                file_path = os.path.join(root, file)
                
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                    
                for line_num, line in enumerate(lines, 1):
                    for pattern in log_patterns:
                        matches = re.finditer(pattern, line, re.IGNORECASE)
                        for match in matches:
                            log_statements.append({
                                'file': file_path,
                                'line': line_num,
                                'level': match.group(1).upper(),
                                'content': match.group(2).strip(),
                                'raw': line.strip()
                            })
    
    return log_statements
```

### Step 3: 匹配日志消息与代码

将日志消息模式与代码中的日志语句进行匹配：

```python
def match_log_to_code(log_pattern, log_statements):
    """
    尝试将日志消息模式匹配到代码中的日志语句
    """
    matches = []
    
    for stmt in log_statements:
        # 提取代码中的字符串字面量
        string_literals = re.findall(r'"([^"]*)"', stmt['content'])
        
        for literal in string_literals:
            # 将代码中的格式化占位符转换为正则
            # %d -> \d+, %f -> [\d.]+, %s -> .*
            regex_pattern = literal
            regex_pattern = re.sub(r'%d', r'\\d+', regex_pattern)
            regex_pattern = re.sub(r'%f', r'[\\d.]+', regex_pattern)
            regex_pattern = re.sub(r'%s', r'.*', regex_pattern)
            regex_pattern = re.sub(r'%\w', r'.*', regex_pattern)  # 其他格式化
            
            # 尝试匹配
            if re.search(regex_pattern, log_pattern):
                matches.append({
                    'log_pattern': log_pattern,
                    'code_location': {
                        'file': stmt['file'],
                        'line': stmt['line'],
                        'function': extract_function_name(stmt['file'], stmt['line']),
                        'code_snippet': stmt['raw']
                    },
                    'confidence': calculate_confidence(log_pattern, literal)
                })
    
    return matches
```

### Step 4: 提取函数上下文

对于匹配到的代码位置，提取函数上下文：

```python
def extract_function_name(file_path, line_num):
    """
    提取指定行所在的函数名
    """
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    # 向上搜索函数定义
    for i in range(line_num - 1, max(0, line_num - 50), -1):
        line = lines[i]
        # C++ 函数定义
        match = re.search(r'(\w+)\s*\([^)]*\)\s*\{', line)
        if match:
            return match.group(1)
        # Python 函数定义
        match = re.search(r'def\s+(\w+)\s*\(', line)
        if match:
            return match.group(1)
    
    return "unknown"

def extract_function_context(file_path, line_num, context_lines=10):
    """
    提取函数上下文（前后各 context_lines 行）
    """
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    start = max(0, line_num - context_lines - 1)
    end = min(len(lines), line_num + context_lines)
    
    return {
        'file': file_path,
        'line_range': [start + 1, end],
        'context': ''.join(lines[start:end])
    }
```

### Step 5: 计算映射覆盖率

统计有多少日志消息成功映射到代码：

```python
def calculate_coverage(log_entries, mappings):
    """
    计算映射覆盖率
    """
    total_entries = len(log_entries)
    mapped_entries = sum(m['count'] for m in mappings)
    
    coverage = mapped_entries / total_entries if total_entries > 0 else 0
    
    # 按模块统计覆盖率
    module_coverage = {}
    for entry in log_entries:
        module = entry.get('module', 'unknown')
        if module not in module_coverage:
            module_coverage[module] = {'total': 0, 'mapped': 0}
        
        module_coverage[module]['total'] += 1
        
        # 检查该条日志是否被映射
        for mapping in mappings:
            if re.search(mapping['log_pattern'], entry['message']):
                module_coverage[module]['mapped'] += 1
                break
    
    for module in module_coverage:
        total = module_coverage[module]['total']
        mapped = module_coverage[module]['mapped']
        module_coverage[module]['coverage'] = mapped / total if total > 0 else 0
    
    return {
        'overall_coverage': coverage,
        'module_coverage': module_coverage,
        'total_entries': total_entries,
        'mapped_entries': mapped_entries,
        'unmapped_entries': total_entries - mapped_entries
    }
```

### Step 6: 输出映射结果

#### 6.1 输出 code-log-mapping.json

```json
{
  "version": "1.0",
  "project_path": "/path/to/project",
  "total_log_patterns": 500,
  "mapped_patterns": 450,
  "mappings": [
    {
      "log_pattern": "Tracked <NUM> features",
      "count": 1500,
      "code_location": {
        "file": "src/tracker.cpp",
        "line": 123,
        "function": "trackFeatures",
        "code_snippet": "LOG(INFO) << \"Tracked \" << num_features << \" features\";"
      },
      "context": {
        "file": "src/tracker.cpp",
        "line_range": [113, 133],
        "context": "void trackFeatures(...) {\n  ...\n  LOG(INFO) << \"Tracked \" << num_features << \" features\";\n  ...\n}"
      },
      "confidence": 0.95,
      "related_modules": ["tracker"]
    }
  ]
}
```

#### 6.2 输出 log-coverage-report.json

```json
{
  "version": "1.0",
  "overall_coverage": 0.90,
  "total_entries": 15000,
  "mapped_entries": 13500,
  "unmapped_entries": 1500,
  "module_coverage": {
    "tracker": {
      "total": 5000,
      "mapped": 4800,
      "coverage": 0.96
    },
    "optimizer": {
      "total": 4000,
      "mapped": 3900,
      "coverage": 0.975
    },
    "viewer": {
      "total": 3000,
      "mapped": 2400,
      "coverage": 0.80
    },
    "system": {
      "total": 3000,
      "mapped": 2400,
      "coverage": 0.80
    }
  }
}
```

### Step 7: 用户反馈

向用户展示映射结果：

```
✅ 代码映射完成

📊 映射统计:
- 总日志条目: 15000
- 成功映射: 13500 (90%)
- 未映射: 1500 (10%)

📦 模块覆盖率:
- tracker: 96% (4800/5000)
- optimizer: 97.5% (3900/4000)
- viewer: 80% (2400/3000)
- system: 80% (2400/3000)

🔍 关键映射:
1. "Tracked <NUM> features" → tracker.cpp:123 (trackFeatures)
2. "Optimization converged in <NUM> iterations" → optimizer.cpp:456 (optimize)
3. "Loop closure detected" → loop_detector.cpp:789 (detectLoop)

⚠️ 未映射的日志 (前10条):
1. "System initialized" (出现 100 次)
2. "Saving map to file" (出现 50 次)
...

是否继续分析特定时间段？(Y/n)
```

## 高级功能

### 交互式代码导航

提供从日志跳转到代码的功能：

```python
def navigate_to_code(file_path, line_num):
    """
    在编辑器中打开指定文件和行
    """
    # VS Code
    os.system(f'code --goto {file_path}:{line_num}')
    
    # 或 Vim
    # os.system(f'vim +{line_num} {file_path}')
    
    # 或 Emacs
    # os.system(f'emacs +{line_num} {file_path}')
```

### 代码变更检测

检测代码变更后，映射是否仍然有效：

```python
def check_mapping_validity(mapping):
    """
    检查映射是否仍然有效（代码是否被修改）
    """
    file_path = mapping['code_location']['file']
    line_num = mapping['code_location']['line']
    
    # 读取当前代码
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    if line_num <= len(lines):
        current_line = lines[line_num - 1]
        # 检查日志语句是否还在
        if mapping['code_location']['code_snippet'] in current_line:
            return True, "映射有效"
        else:
            return False, "代码已修改"
    else:
        return False, "行号超出范围"
```

## 错误处理

### 错误 1: 无法找到代码文件
```
❌ 无法找到代码文件

日志消息: "Tracked 150 features"
推测位置: src/tracker.cpp:123

文件不存在或路径错误。

解决方案:
1. 检查项目路径是否正确
2. 手动指定代码位置
3. 跳过此映射
```

### 错误 2: 映射置信度低
```
⚠️ 映射置信度低

日志消息: "Processing frame <NUM>"
匹配到 3 个可能的代码位置:
1. src/frontend.cpp:100 (置信度: 0.6)
2. src/tracker.cpp:200 (置信度: 0.5)
3. src/system.cpp:300 (置信度: 0.4)

解决方案:
1. 手动选择正确的映射
2. 使用上下文进一步分析
3. 标记为不确定
```

## 注意事项

1. **多语言支持**: 支持 C++、Python、C 等语言
2. **模板日志**: 处理带格式化占位符的日志（%d, %f, %s 等）
3. **动态日志**: 处理运行时构造的日志消息（较难映射）
4. **第三方库**: 跳过第三方库的日志（通常不需要映射）
5. **性能优化**: 大项目时使用增量映射（只映射新增的日志）
