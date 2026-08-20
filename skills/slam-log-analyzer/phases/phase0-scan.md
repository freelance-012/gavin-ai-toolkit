# Phase 0: 日志扫描

## 目标

扫描项目中的日志文件，识别日志格式和位置，为后续解析做准备。

## 输入

- `project_path`: 项目根目录
- `project-spec.md`: 项目规格文件（包含日志配置）

## 输出

- `log-scan-report.json`: 扫描结果，包含找到的日志文件和识别的格式

## 执行步骤

### Step 1: 读取项目规格

从 `project-spec.md` 中提取日志相关配置：

```yaml
## 日志配置
log_directory: "/path/to/logs"
log_format: "ros"  # ros / custom / plain
log_pattern: "*.log"
timestamp_format: "unix"  # unix / datetime / custom
```

如果 spec 中没有日志配置，提示用户先运行 slam-project-profiler。

### Step 2: 扫描日志文件

在以下位置搜索日志文件：

1. **spec 指定的目录**
   ```bash
   find {log_directory} -name "{log_pattern}" -type f
   ```

2. **常见日志位置**（如果 spec 未指定）
   ```bash
   # ROS 日志
   ~/.ros/log/
   {project}/logs/
   
   # 自定义日志
   {project}/output/
   {project}/results/
   
   # 系统日志
   /var/log/
   ```

3. **按时间排序**
   ```bash
   ls -lt {log_files} | head -20
   ```

### Step 3: 识别日志格式

对找到的日志文件，采样前 10 行识别格式：

#### 3.1 ROS 日志格式
```
正则: ^\[(INFO|WARN|ERROR|DEBUG|FATAL)\] \[([\d.]+)\]: \[(\w+)\] (.*)$
示例: [INFO] [1623456789.123456]: [tracker] Tracked 150 features
```

#### 3.2 自定义格式
```
正则: ^\[([\d-]+ [\d:.]+)\] \[(\w+)\] \[(\w+)\] (\w+\.cpp:\d+) - (.*)$
示例: [2024-01-01 12:00:00.123] [INFO] [tracker] tracker.cpp:123 - Tracked 150 features
```

#### 3.3 纯文本格式
```
正则: ^([\d.]+) (\w+) (.*)$
示例: 1623456789.123 INFO Tracked 150 features
```

### Step 4: 验证时间戳

检查时间戳格式：

1. **Unix 时间戳**（秒）
   ```
   范围: 1e9 - 2e9 (2001-2033年)
   示例: 1623456789.123
   ```

2. **日期时间格式**
   ```
   格式: YYYY-MM-DD HH:MM:SS.mmm
   示例: 2024-01-01 12:00:00.123
   ```

3. **相对时间**
   ```
   格式: 从启动开始的秒数
   示例: 123.456
   ```

### Step 5: 生成扫描报告

输出 `log-scan-report.json`:

```json
{
  "scan_time": "2024-01-01T12:00:00Z",
  "log_files": [
    {
      "path": "/path/to/log1.txt",
      "size_mb": 15.2,
      "format": "ros",
      "timestamp_format": "unix",
      "first_timestamp": 1623456789.123,
      "last_timestamp": 1623457089.456,
      "duration_sec": 300.333,
      "line_count": 15000,
      "modules": ["tracker", "optimizer", "viewer"]
    }
  ],
  "summary": {
    "total_files": 1,
    "total_size_mb": 15.2,
    "total_duration_sec": 300.333,
    "total_entries": 15000
  }
}
```

### Step 6: 用户确认

向用户展示扫描结果：

```
📋 日志扫描结果

找到 1 个日志文件:

1. /path/to/log1.txt
   - 格式: ROS 日志
   - 大小: 15.2 MB
   - 时间范围: 1623456789.123 - 1623457089.456 (300.3 秒)
   - 条目数: 15000
   - 模块: tracker, optimizer, viewer

是否使用此日志进行分析？(Y/n)
```

如果用户不满意，提供选项：
1. 选择其他日志文件
2. 指定日志文件路径
3. 重新扫描

## 错误处理

### 错误 1: 未找到日志文件
```
❌ 未找到日志文件

请检查:
1. 项目规格中的日志目录是否正确
2. 是否运行过系统并生成日志
3. 日志文件是否已清理

解决方案:
- 运行系统生成日志
- 指定日志文件路径: slam-log-analyzer --log /path/to/log.txt
```

### 错误 2: 无法识别日志格式
```
❌ 无法识别日志格式

日志样本:
```
{前3行内容}
```

请提供日志格式信息:
1. 时间戳格式（unix/datetime/relative）
2. 日志级别位置
3. 模块名位置
4. 消息内容位置
```

## 注意事项

1. **大文件处理**: 如果日志文件 > 100MB，提示用户可能需要较长时间
2. **压缩日志**: 支持 .gz 压缩文件（使用 zcat 读取）
3. **多文件合并**: 如果找到多个日志文件，询问是否合并分析
4. **编码问题**: 检测文件编码（UTF-8 / GBK），避免乱码
