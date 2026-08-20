# Session Logger - AI 会话日志记录系统

跨平台的 AI 会话日志记录工具，支持 Claude Code 和 CodeBuddy。

## 功能

自动记录 AI 会话中的所有操作：
- ✅ 工具调用（Bash、Read、Write、Edit 等）
- ✅ 文件读写记录
- ✅ 命令执行记录
- ✅ 会话统计和摘要

## 支持的平台

- **Claude Code**：使用 `.claude/` 目录
- **CodeBuddy**：使用 `.codebuddy/` 目录

脚本会自动检测当前平台，无需手动配置。

## 快速开始

### 部署到项目

```bash
# 部署到 Claude Code 项目
./deploy-hooks.sh claude /path/to/project

# 部署到 CodeBuddy 项目
./deploy-hooks.sh codebuddy /path/to/project
```

### 使用

部署后，hook 会自动运行。每次 AI 会话都会在项目的 `.claude/logs/` 或 `.codebuddy/logs/` 目录下生成日志。

### 查看日志

```bash
# 查看最新会话摘要
cat /path/to/project/.claude/logs/latest/session-summary.md

# 查看最新会话详细日志（JSON 格式）
cat /path/to/project/.claude/logs/latest/session.jsonl

# 列出所有会话日志
ls -la /path/to/project/.claude/logs/
```

## 日志结构

每次会话会在 `logs/{timestamp}_{session_id}/` 目录下生成：

```
{timestamp}_{session_id}/
├── session.jsonl          # 主日志（JSON Lines 格式）
├── session-summary.md     # 人类可读的摘要报告
├── files-read.log         # 读取的文件列表
├── files-written.log      # 写入的文件列表
├── commands.log           # 执行的命令列表
└── .platform              # 平台标识（.claude 或 .codebuddy）
```

### session.jsonl 格式

每行一个 JSON 对象：

```json
{"ts":"2026-08-20T14:23:45+08:00","event":"session_start","sid":"abc123","cwd":"/path/to/project"}
{"ts":"2026-08-20T14:23:46+08:00","event":"tool_use","tool":"Bash","input":{"command":"ls -la"},"sid":"abc123"}
{"ts":"2026-08-20T14:23:47+08:00","event":"tool_result","tool":"Bash","sid":"abc123"}
{"ts":"2026-08-20T14:23:50+08:00","event":"session_end","sid":"abc123"}
```

### session-summary.md 示例

```markdown
# 会话日志摘要

> **会话 ID**: abc123
> **开始时间**: 2026-08-20T14:23:45+08:00
> **结束时间**: 2026-08-20T14:24:00+08:00
> **工作目录**: /path/to/project

## 执行统计

- **工具调用总数**: 15
  - Bash: 5 次
  - Read: 8 次
  - Write/Edit: 2 次

## 文件操作

### 读取的文件 (8 个)

| 时间 | 文件路径 |
|------|---------|
| 2026-08-20T14:23:46+08:00 | `/path/to/file1.txt` |
| ... | ... |

### 写入的文件 (2 个)

| 时间 | 文件路径 |
|------|---------|
| 2026-08-20T14:23:50+08:00 | `/path/to/output.md` |
| ... | ... |

## 命令执行 (5 个)

| 时间 | 命令 |
|------|------|
| 2026-08-20T14:23:46+08:00 | `ls -la` |
| ... | ... |
```

## 手动配置

如果不想使用部署脚本，可以手动配置：

### 1. 复制 hook 脚本

```bash
# Claude Code
mkdir -p /path/to/project/.claude/hooks/session-logger
cp hooks/session-logger/*.sh /path/to/project/.claude/hooks/session-logger/
chmod +x /path/to/project/.claude/hooks/session-logger/*.sh

# CodeBuddy
mkdir -p /path/to/project/.codebuddy/hooks/session-logger
cp hooks/session-logger/*.sh /path/to/project/.codebuddy/hooks/session-logger/
chmod +x /path/to/project/.codebuddy/hooks/session-logger/*.sh
```

### 2. 创建 settings.json

在项目的 `.claude/settings.json` 或 `.codebuddy/settings.json` 中添加：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": ".claude/hooks/session-logger/init.sh"}]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": ".claude/hooks/session-logger/pre-tool.sh"}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": ".claude/hooks/session-logger/post-tool.sh"}]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": ".claude/hooks/session-logger/finalize.sh"}]
      }
    ]
  }
}
```

**注意**：如果使用 CodeBuddy，将路径中的 `.claude` 替换为 `.codebuddy`。

## 高级用法

### 强制指定平台

如果自动检测失败，可以设置环境变量：

```bash
export CLAUDE_PLATFORM=claude    # 强制使用 Claude Code 模式
export CLAUDE_PLATFORM=codebuddy # 强制使用 CodeBuddy 模式
```

### 查询历史日志

```bash
# 查找特定会话 ID 的日志
find /path/to/project/.claude/logs/ -name "*abc123*"

# 查找特定日期的日志
ls /path/to/project/.claude/logs/20260820_*

# 统计所有会话的工具调用次数
for dir in /path/to/project/.claude/logs/*/; do
    if [ -f "$dir/session.jsonl" ]; then
        count=$(grep -c '"event":"tool_use"' "$dir/session.jsonl")
        echo "$dir: $count 次工具调用"
    fi
done
```

### 与其他 skill 集成

Session logger 可以与其他 skill 配合使用：

- **slam-eval-runner**：查看评估过程中执行了哪些命令
- **slam-log-analyzer**：追踪日志分析过程中的文件操作
- **slam-debug-helper**：回溯调试过程中的推理路径

## 故障排除

### Hook 没有运行

1. 检查 `settings.json` 是否存在且格式正确
2. 检查 hook 脚本是否有执行权限：`ls -la .claude/hooks/session-logger/`
3. 检查 hook 脚本路径是否正确

### 日志目录没有创建

1. 检查 `SessionStart` hook 是否运行：查看是否有输出信息
2. 手动运行 init.sh 测试：`echo '{"session_id":"test","cwd":"'$(pwd)'"}' | .claude/hooks/session-logger/init.sh`

### Python 解析失败

脚本依赖 `python3` 来解析 JSON。确保系统已安装 Python 3：

```bash
python3 --version
```

## 技术细节

### 平台检测逻辑

脚本按以下优先级检测平台：
1. 环境变量 `CLAUDE_PLATFORM`
2. 目录存在性：`.claude/` > `.codebuddy/` > `.workbuddy/`
3. 默认使用 `.claude/`

### 依赖

- bash
- python3（用于 JSON 解析）
- 标准 Unix 工具（date, ln, mkdir, cp, chmod）

## 许可证

MIT License
