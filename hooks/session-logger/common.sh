#!/bin/bash
# Session Logger - 公共函数库
# 所有 hook 脚本 source 此文件

# 根据脚本自身路径确定平台
# 原理：脚本在 .claude/hooks/ 下就是 Claude，在 .codebuddy/hooks/ 下就是 CodeBuddy
detect_platform() {
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 从脚本路径中提取配置目录名
    # 路径格式: {project}/{config_dir}/hooks/session-logger/
    if [[ "$script_path" == *"/.claude/hooks/"* ]]; then
        echo ".claude"
    elif [[ "$script_path" == *"/.codebuddy/hooks/"* ]]; then
        echo ".codebuddy"
    elif [[ "$script_path" == *"/.workbuddy/hooks/"* ]]; then
        echo ".workbuddy"
    else
        # 兜底：从路径中倒数第3层目录名推断
        local config_dir
        config_dir=$(echo "$script_path" | grep -oP '/\.?\K[^/]+(?=/hooks/session-logger$)')
        if [ -n "$config_dir" ]; then
            echo ".${config_dir}"
        else
            echo ".claude"  # 最终兜底
        fi
    fi
}

# 从 JSON stdin 中提取字段（使用 python3）
json_get() {
    local input="$1"
    local field="$2"
    local default="${3:-}"
    echo "$input" | python3 -c "import sys, json; print(json.load(sys.stdin).get('${field}', '${default}'))" 2>/dev/null || echo "$default"
}

# 查找当前会话的日志目录
# 优先使用 .platform 文件，其次查找 latest 链接
find_log_dir() {
    local cwd="$1"
    local config_dir
    config_dir="$(detect_platform)"

    # 优先使用 latest 链接（在正确的平台目录下）
    local latest_link="${cwd}/${config_dir}/logs/latest"
    if [ -L "$latest_link" ]; then
        readlink -f "$latest_link"
        return
    fi

    # 兜底：找最新的日志目录
    local log_dir
    log_dir=$(ls -td "${cwd}/${config_dir}/logs/"* 2>/dev/null | head -1)
    if [ -n "$log_dir" ]; then
        echo "$log_dir"
    fi
}
