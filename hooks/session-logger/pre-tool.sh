#!/bin/bash
# Session Logger - PreToolUse Hook
# 在工具执行前记录工具调用信息

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 从 stdin 读取 JSON
INPUT=$(cat)

# 提取工具调用信息
SESSION_ID=$(json_get "$INPUT" "session_id" "unknown")
CWD=$(json_get "$INPUT" "cwd" "$(pwd)")
TOOL_NAME=$(json_get "$INPUT" "tool_name" "unknown")
TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin).get('tool_input', {})))" 2>/dev/null || echo "{}")

# 根据脚本自身路径确定平台，查找日志目录
CONFIG_DIR="$(detect_platform)"
LOG_DIR="$(find_log_dir "$CWD")"

if [ -z "$LOG_DIR" ]; then
    # 如果还没有日志目录，跳过记录
    exit 0
fi

# 记录工具调用
LOG_ENTRY="{\"ts\":\"$(date -Iseconds)\",\"event\":\"tool_use\",\"tool\":\"${TOOL_NAME}\",\"input\":${TOOL_INPUT},\"sid\":\"${SESSION_ID}\"}"

# 追加到 session.jsonl
echo "$LOG_ENTRY" >> "${LOG_DIR}/session.jsonl"

# 对于文件操作，额外记录到专门的文件
if [[ "$TOOL_NAME" == "Read" ]]; then
    FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null || echo "")
    if [ -n "$FILE_PATH" ]; then
        echo "$(date -Iseconds)|${FILE_PATH}" >> "${LOG_DIR}/files-read.log"
    fi
elif [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
    FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_path', ''))" 2>/dev/null || echo "")
    if [ -n "$FILE_PATH" ]; then
        echo "$(date -Iseconds)|${FILE_PATH}" >> "${LOG_DIR}/files-written.log"
    fi
elif [[ "$TOOL_NAME" == "Bash" ]]; then
    COMMAND=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('command', ''))" 2>/dev/null || echo "")
    if [ -n "$COMMAND" ]; then
        # 只记录前 200 个字符，避免日志过大
        SHORT_CMD=$(echo "$COMMAND" | head -c 200)
        echo "$(date -Iseconds)|${SHORT_CMD}" >> "${LOG_DIR}/commands.log"
    fi
fi

# 允许工具继续执行
exit 0
