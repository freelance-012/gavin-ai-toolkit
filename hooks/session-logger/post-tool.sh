#!/bin/bash
# Session Logger - PostToolUse Hook
# 在工具执行后记录执行结果和耗时

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 从 stdin 读取 JSON
INPUT=$(cat)

# 提取工具结果信息
SESSION_ID=$(json_get "$INPUT" "session_id" "unknown")
CWD=$(json_get "$INPUT" "cwd" "$(pwd)")
TOOL_NAME=$(json_get "$INPUT" "tool_name" "unknown")

# 根据脚本自身路径确定平台，查找日志目录
CONFIG_DIR="$(detect_platform)"
LOG_DIR="$(find_log_dir "$CWD")"

if [ -z "$LOG_DIR" ]; then
    exit 0
fi

# 记录工具结果（简化版，不记录完整的 tool_output 避免日志过大）
LOG_ENTRY="{\"ts\":\"$(date -Iseconds)\",\"event\":\"tool_result\",\"tool\":\"${TOOL_NAME}\",\"sid\":\"${SESSION_ID}\"}"

# 追加到 session.jsonl
echo "$LOG_ENTRY" >> "${LOG_DIR}/session.jsonl"

# 更新统计计数器
STATS_FILE="${LOG_DIR}/stats.tmp"
if [ ! -f "$STATS_FILE" ]; then
    echo "tool_count=0" > "$STATS_FILE"
    echo "bash_count=0" >> "$STATS_FILE"
    echo "read_count=0" >> "$STATS_FILE"
    echo "write_count=0" >> "$STATS_FILE"
fi

# 读取当前计数
source "$STATS_FILE"

# 更新计数
tool_count=$((tool_count + 1))
case "$TOOL_NAME" in
    "Bash")
        bash_count=$((bash_count + 1))
        ;;
    "Read")
        read_count=$((read_count + 1))
        ;;
    "Write"|"Edit")
        write_count=$((write_count + 1))
        ;;
esac

# 写回统计
cat > "$STATS_FILE" <<EOF
tool_count=${tool_count}
bash_count=${bash_count}
read_count=${read_count}
write_count=${write_count}
EOF

exit 0
