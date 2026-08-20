# slam-log-analyzer

SLAM 系统日志分析工具。解析日志文件，建立日志与代码的映射关系，分析异常时间段，辅助添加调试日志。

## 定位

**日志分析 skill**——当需要深入理解系统运行时行为时，通过分析日志定位问题。

**核心能力**：
1. 解析 SLAM 系统的日志文件（ROS log、自定义日志等）
2. 建立日志消息与源代码位置的映射
3. 分析特定时间段内的日志（如误差突增期间）
4. 辅助设计和添加调试日志（代码插桩）

## 触发词

- "分析日志"
- "看看这段时间发生了什么"
- "加一些调试日志"
- "log"
- "这个时间段系统怎么了"
- "帮我插桩"

## 依赖

- `project-spec.md`（由 slam-project-profiler 生成）
- 可选：eval-runner 的评估结果（提供异常时间段）
- 可选：debug-helper 的诊断结果（提供需要分析的时间段）

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_path | string | ✅ | 项目根目录绝对路径 |
| log_path | string | ⬜ | 日志文件路径（默认从 spec 读取） |
| time_range | string | ⬜ | 分析的时间范围（格式："start-end"，单位：秒） |

## 输出产物

```
{project}/.specs/log-analysis/
└── {timestamp}_{session_id}/
    ├── log-index.json            # 日志索引（时间戳 → 日志条目）
    ├── code-log-mapping.json     # 代码-日志映射（代码位置 → 日志消息）
    ├── analysis-report.md        # 分析报告
    └── instrument-patches/       # 插桩补丁（如果有）
        └── *.patch
```

## 五步法工作流

```
Phase 0: 日志扫描      → 扫描项目中的日志文件，识别日志格式
Phase 1: 日志解析      → 解析日志，建立时间索引
Phase 2: 代码映射      → 建立日志消息与源代码的映射关系
Phase 3: 时段分析      → 分析指定时间段内的日志
Phase 4: 插桩设计      → 设计并添加调试日志（可选）
```

### 依赖关系

```
Phase 0 ──────→ Phase 1 ──────→ Phase 2 ──────→ Phase 3
（日志扫描）     （日志解析）      （代码映射）      （时段分析）
                                                    ↓
                                              Phase 4（插桩设计）
```

## 执行模式

### 模式 A：完整分析（默认）

用户说："分析日志" 或 "log"

执行流程：
1. 检查 spec 文件是否存在
2. 按 Phase 0 → 1 → 2 → 3 顺序执行
3. 生成日志索引和分析报告

### 模式 B：指定时间段分析

用户说："分析 10-20 秒的日志" 或 "这段时间发生了什么"

执行流程：
1. Phase 0-2：扫描、解析、映射
2. Phase 3：分析指定时间段
3. 生成时段分析报告

### 模式 C：代码插桩

用户说："帮我加一些调试日志" 或 "插桩"

执行流程：
1. Phase 0-2：扫描、解析、映射
2. Phase 4：设计并添加调试日志
3. 生成插桩补丁

### 模式 D：联合分析

用户说："分析误差突增时的日志"（配合 eval-runner）

执行流程：
1. 从 eval-runner 获取异常时间段
2. Phase 0-3：分析该时间段的日志
3. 结合误差数据给出诊断建议

## Phase 编排详情

| Phase | 文件 | 名称 | 可独立执行 |
|-------|------|------|-----------|
| 0 | `phases/phase0-scan.md` | 日志扫描 | ✅ |
| 1 | `phases/phase1-parse.md` | 日志解析 | ✅（需 Phase 0） |
| 2 | `phases/phase2-map.md` | 代码映射 | ✅（需 Phase 1） |
| 3 | `phases/phase3-analyze.md` | 时段分析 | ✅（需 Phase 2） |
| 4 | `phases/phase4-instrument.md` | 插桩设计 | ✅（需 Phase 2） |

## 输出模板

| 模板文件 | 用途 |
|---------|------|
| `templates/log-analysis-template.md` | 分析报告格式 |

## 支持的日志格式

### ROS 日志
```
[INFO] [1623456789.123456]: [node_name] Message text
[WARN] [1623456789.123456]: [node_name] Warning message
[ERROR] [1623456789.123456]: [node_name] Error message
```

### 自定义日志
```
[2024-01-01 12:00:00.123] [INFO] [module_name] file.cpp:123 - Message
[1623456789.123] [DEBUG] [tracker] Tracked 150 features
```

### 纯文本日志
```
1623456789.123 INFO Tracked 150 features
1623456789.234 DEBUG Optimization converged in 5 iterations
```

## 全局约定

### 日志索引格式

```json
{
  "version": "1.0",
  "log_file": "/path/to/log.txt",
  "log_format": "ros",
  "entries": [
    {
      "timestamp": 1623456789.123456,
      "level": "INFO",
      "module": "tracker",
      "message": "Tracked 150 features",
      "line_number": 1
    }
  ]
}
```

### 代码-日志映射格式

```json
{
  "version": "1.0",
  "mappings": [
    {
      "log_pattern": "Tracked.*features",
      "code_location": {
        "file": "src/tracker.cpp",
        "line": 123,
        "function": "trackFeatures"
      },
      "log_level": "INFO",
      "module": "tracker"
    }
  ]
}
```

### 分析报告格式

分析报告必须包含：
1. 日志概览（文件、格式、时间范围、条目数）
2. 代码映射统计（覆盖率、关键模块）
3. 时段分析结果（关键事件、异常模式）
4. 建议（下一步操作、插桩建议）

### 插桩规范

添加的调试日志必须：
1. 使用项目现有的日志框架
2. 包含时间戳和模块信息
3. 不改变原有逻辑
4. 易于后续移除（使用统一的标记）

## 常见分析场景

### 场景 1：分析误差突增期间
```
输入: eval-runner 检测到 10-15 秒误差突增
分析:
1. 提取 10-15 秒的日志
2. 统计关键指标变化（特征数、内点数、优化迭代次数）
3. 识别异常模式（如特征数骤降、优化发散）
4. 关联代码位置
输出: 分析报告 + 可能的根因
```

### 场景 2：分析系统卡死
```
输入: 系统在 20 秒后无响应
分析:
1. 查看 20 秒前的日志
2. 识别最后执行的代码路径
3. 检查是否有死锁或无限循环的迹象
4. 建议插桩位置
输出: 卡死原因分析 + 插桩方案
```

### 场景 3：优化性能瓶颈
```
输入: 系统帧率低
分析:
1. 统计各模块耗时（通过日志时间戳差）
2. 识别耗时最长的模块
3. 分析该模块的日志模式
4. 建议性能优化插桩
输出: 性能分析报告 + 优化建议
```
