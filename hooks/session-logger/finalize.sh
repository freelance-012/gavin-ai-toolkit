#!/bin/bash
# Session Logger - SessionEnd Hook
# 会话结束时生成摘要报告

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 从 stdin 读取 JSON
INPUT=$(cat)

# 提取会话信息
SESSION_ID=$(json_get "$INPUT" "session_id" "unknown")
CWD=$(json_get "$INPUT" "cwd" "$(pwd)")

# 根据脚本自身路径确定平台，查找日志目录
CONFIG_DIR="$(detect_platform)"
LOG_DIR="$(find_log_dir "$CWD")"

if [ -z "$LOG_DIR" ]; then
    exit 0
fi

# 记录会话结束
echo "{\"ts\":\"$(date -Iseconds)\",\"event\":\"session_end\",\"sid\":\"${SESSION_ID}\"}" >> "${LOG_DIR}/session.jsonl"

# 读取统计数据
STATS_FILE="${LOG_DIR}/stats.tmp"
if [ -f "$STATS_FILE" ]; then
    source "$STATS_FILE"
else
    tool_count=0
    bash_count=0
    read_count=0
    write_count=0
fi

# 从 session.jsonl 提取时间信息
START_TIME=$(head -1 "${LOG_DIR}/session.jsonl" | python3 -c "import sys, json; print(json.load(sys.stdin).get('ts', ''))" 2>/dev/null || echo "")
END_TIME=$(date -Iseconds)

# 统计文件操作
FILES_READ_COUNT=0
FILES_WRITTEN_COUNT=0
COMMANDS_COUNT=0

if [ -f "${LOG_DIR}/files-read.log" ]; then
    FILES_READ_COUNT=$(wc -l < "${LOG_DIR}/files-read.log")
fi

if [ -f "${LOG_DIR}/files-written.log" ]; then
    FILES_WRITTEN_COUNT=$(wc -l < "${LOG_DIR}/files-written.log")
fi

if [ -f "${LOG_DIR}/commands.log" ]; then
    COMMANDS_COUNT=$(wc -l < "${LOG_DIR}/commands.log")
fi

# 生成摘要报告
cat > "${LOG_DIR}/session-summary.md" <<EOF
# 会话日志摘要

> **会话 ID**: ${SESSION_ID}
> **平台**: ${CONFIG_DIR}
> **开始时间**: ${START_TIME}
> **结束时间**: ${END_TIME}
> **工作目录**: ${CWD}

## 执行统计

- **工具调用总数**: ${tool_count}
  - Bash: ${bash_count} 次
  - Read: ${read_count} 次
  - Write/Edit: ${write_count} 次

## 文件操作

### 读取的文件 (${FILES_READ_COUNT} 个)

EOF

# 添加读取的文件列表
if [ -f "${LOG_DIR}/files-read.log" ] && [ -s "${LOG_DIR}/files-read.log" ]; then
    echo "| 时间 | 文件路径 |" >> "${LOG_DIR}/session-summary.md"
    echo "|------|---------|" >> "${LOG_DIR}/session-summary.md"
    while IFS='|' read -r timestamp filepath; do
        echo "| ${timestamp} | \`${filepath}\` |" >> "${LOG_DIR}/session-summary.md"
    done < "${LOG_DIR}/files-read.log"
else
    echo "_无_" >> "${LOG_DIR}/session-summary.md"
fi

cat >> "${LOG_DIR}/session-summary.md" <<EOF

### 写入的文件 (${FILES_WRITTEN_COUNT} 个)

EOF

# 添加写入的文件列表
if [ -f "${LOG_DIR}/files-written.log" ] && [ -s "${LOG_DIR}/files-written.log" ]; then
    echo "| 时间 | 文件路径 |" >> "${LOG_DIR}/session-summary.md"
    echo "|------|---------|" >> "${LOG_DIR}/session-summary.md"
    while IFS='|' read -r timestamp filepath; do
        echo "| ${timestamp} | \`${filepath}\` |" >> "${LOG_DIR}/session-summary.md"
    done < "${LOG_DIR}/files-written.log"
else
    echo "_无_" >> "${LOG_DIR}/session-summary.md"
fi

cat >> "${LOG_DIR}/session-summary.md" <<EOF

## 命令执行 (${COMMANDS_COUNT} 个)

EOF

# 添加执行的命令列表
if [ -f "${LOG_DIR}/commands.log" ] && [ -s "${LOG_DIR}/commands.log" ]; then
    echo "| 时间 | 命令 |" >> "${LOG_DIR}/session-summary.md"
    echo "|------|------|" >> "${LOG_DIR}/session-summary.md"
    while IFS='|' read -r timestamp command; do
        # 转义 markdown 特殊字符
        escaped_cmd=$(echo "$command" | sed 's/|/\\|/g' | head -c 100)
        echo "| ${timestamp} | \`${escaped_cmd}\` |" >> "${LOG_DIR}/session-summary.md"
    done < "${LOG_DIR}/commands.log"
else
    echo "_无_" >> "${LOG_DIR}/session-summary.md"
fi

# 清理临时文件
rm -f "$STATS_FILE"

echo "Session log finalized: ${LOG_DIR}/session-summary.md"

exit 0
