#!/bin/bash
# Session Logger - SessionStart Hook
# 初始化会话日志目录和文件

set -e

# 加载公共函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 从 stdin 读取 JSON
INPUT=$(cat)

# 提取会话信息
SESSION_ID=$(json_get "$INPUT" "session_id" "unknown")
CWD=$(json_get "$INPUT" "cwd" "$(pwd)")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 根据脚本自身路径确定平台
CONFIG_DIR="$(detect_platform)"

# 日志目录
LOG_DIR="${CWD}/${CONFIG_DIR}/logs/${TIMESTAMP}_${SESSION_ID}"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 初始化 session.jsonl
echo "{\"ts\":\"$(date -Iseconds)\",\"event\":\"session_start\",\"sid\":\"${SESSION_ID}\",\"cwd\":\"${CWD}\",\"platform\":\"${CONFIG_DIR}\"}" > "${LOG_DIR}/session.jsonl"

# 更新 latest 软链接
LATEST_LINK="${CWD}/${CONFIG_DIR}/logs/latest"
rm -f "$LATEST_LINK"
ln -s "${TIMESTAMP}_${SESSION_ID}" "$LATEST_LINK"

# 保存平台信息到日志目录
echo "$CONFIG_DIR" > "${LOG_DIR}/.platform"

# 输出初始化信息
echo "Session logger initialized (${CONFIG_DIR}): ${LOG_DIR}"

exit 0
