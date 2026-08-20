#!/bin/bash
# Session Logger Hook 部署脚本
# 用法: ./deploy-hooks.sh <platform> <project_path>
# platform: claude | codebuddy
# project_path: 目标项目路径

set -e

if [ $# -lt 2 ]; then
    echo "用法: $0 <platform> <project_path>"
    echo "  platform: claude | codebuddy"
    echo "  project_path: 目标项目路径"
    exit 1
fi

PLATFORM=$1
PROJECT_PATH=$2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 确定配置目录
case "$PLATFORM" in
    claude)
        CONFIG_DIR=".claude"
        ;;
    codebuddy)
        CONFIG_DIR=".codebuddy"
        ;;
    *)
        echo "错误: 不支持的平台 '$PLATFORM'"
        echo "支持的平台: claude, codebuddy"
        exit 1
        ;;
esac

# 检查项目路径
if [ ! -d "$PROJECT_PATH" ]; then
    echo "错误: 项目路径不存在: $PROJECT_PATH"
    exit 1
fi

# 创建配置目录
mkdir -p "${PROJECT_PATH}/${CONFIG_DIR}"

# 复制 hook 脚本
HOOKS_SRC="${SCRIPT_DIR}/session-logger"
HOOKS_DST="${PROJECT_PATH}/${CONFIG_DIR}/hooks/session-logger"

echo "部署 session-logger hooks 到 ${PROJECT_PATH}/${CONFIG_DIR}/hooks/"

mkdir -p "$HOOKS_DST"
cat "${HOOKS_SRC}/common.sh" > "$HOOKS_DST/common.sh"
cat "${HOOKS_SRC}/init.sh" > "$HOOKS_DST/init.sh"
cat "${HOOKS_SRC}/pre-tool.sh" > "$HOOKS_DST/pre-tool.sh"
cat "${HOOKS_SRC}/post-tool.sh" > "$HOOKS_DST/post-tool.sh"
cat "${HOOKS_SRC}/finalize.sh" > "$HOOKS_DST/finalize.sh"

# 设置执行权限
chmod +x "${HOOKS_DST}/"*.sh

# 获取项目的绝对路径
PROJECT_ABS_PATH="$(cd "$PROJECT_PATH" && pwd)"
HOOKS_ABS_PATH="${PROJECT_ABS_PATH}/${CONFIG_DIR}/hooks/session-logger"

# 生成 settings.json（如果不存在则创建，存在则更新）
SETTINGS_FILE="${PROJECT_PATH}/${CONFIG_DIR}/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    echo "警告: ${SETTINGS_FILE} 已存在"
    echo "请手动添加 hooks 配置，或备份后重新运行此脚本"
    echo ""
    echo "需要添加的配置："
    cat <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "${HOOKS_ABS_PATH}/init.sh"}]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "${HOOKS_ABS_PATH}/pre-tool.sh"}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "${HOOKS_ABS_PATH}/post-tool.sh"}]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "${HOOKS_ABS_PATH}/finalize.sh"}]
      }
    ]
  }
}
EOF
else
    # 创建新的 settings.json，使用绝对路径
    cat > "$SETTINGS_FILE" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "${HOOKS_ABS_PATH}/init.sh"}]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "${HOOKS_ABS_PATH}/pre-tool.sh"}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "${HOOKS_ABS_PATH}/post-tool.sh"}]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "${HOOKS_ABS_PATH}/finalize.sh"}]
      }
    ]
  }
}
EOF
    echo "已创建 ${SETTINGS_FILE}"
fi

echo ""
echo "✅ Session logger hooks 部署完成！"
echo ""
echo "日志位置: ${PROJECT_PATH}/${CONFIG_DIR}/logs/"
echo "查看最新日志: cat ${PROJECT_PATH}/${CONFIG_DIR}/logs/latest/session-summary.md"
