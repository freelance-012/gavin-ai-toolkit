# Phase 1: 自动构建

## 目标

自动编译项目，捕获构建错误，提供清晰的错误信息。

## 触发词

- "构建项目"
- "build project"
- "编译"

## 依赖

Phase 0 的 optimization-config.json

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| config | json | ✅ | Phase 0 的优化配置 |
| iteration_id | int | ⬜ | 当前迭代编号（用于日志命名） |

## 输出产物

- `{session_dir}/iterations/iter_{NNN}/build.log`

## 执行步骤

### Step 1: 准备构建目录

```bash
cd {project_path}
build_dir={build_config.build_dir}

# 如果构建目录不存在，创建它
if [ ! -d "$build_dir" ]; then
    mkdir -p "$build_dir"
fi

cd "$build_dir"
```

### Step 2: 执行构建命令

```bash
# 记录构建开始时间
start_time=$(date +%s)

# 执行构建命令，捕获输出
{build_config.command} > build.log 2>&1
exit_code=$?

# 记录构建结束时间
end_time=$(date +%s)
duration=$((end_time - start_time))
```

### Step 3: 分析构建结果

```python
if exit_code == 0:
    # 构建成功
    log("✅ 构建成功 (耗时 {duration}s)")
else:
    # 构建失败，分析错误
    error_lines = parse_build_log("build.log")
    
    # 提取关键错误信息
    errors = []
    for line in error_lines:
        if "error:" in line.lower():
            errors.append(line)
    
    if errors:
        log("❌ 构建失败")
        log("\n错误信息:")
        for err in errors[:5]:  # 最多显示5个错误
            log(f"  {err}")
        
        # 尝试诊断错误类型
        error_type = diagnose_build_error(errors)
        if error_type:
            log(f"\n诊断: {error_type}")
    else:
        log("❌ 构建失败 (未知错误)")
        log("查看完整日志: build.log")
```

### Step 4: 错误诊断

根据错误信息，提供诊断和建议：

```python
def diagnose_build_error(errors):
    """
    诊断构建错误类型
    """
    error_text = " ".join(errors).lower()
    
    # 语法错误
    if "undeclared identifier" in error_text or "not declared" in error_text:
        return "代码修改引入语法错误（未声明的标识符）"
    
    # 类型错误
    if "no matching function" in error_text or "cannot convert" in error_text:
        return "类型不匹配或函数签名错误"
    
    # 缺少头文件
    if "file not found" in error_text and ".h" in error_text:
        return "缺少头文件（可能是 #include 错误）"
    
    # 链接错误
    if "undefined reference" in error_text:
        return "链接错误（缺少库或符号未定义）"
    
    # CMake 错误
    if "cmake error" in error_text:
        return "CMake 配置错误"
    
    return None
```

### Step 5: 提供修复建议

```python
def suggest_build_fix(error_type, errors):
    """
    提供构建错误修复建议
    """
    suggestions = []
    
    if "语法错误" in error_type:
        suggestions.append("检查最近修改的代码，确认变量/函数已正确声明")
        suggestions.append("检查拼写错误和大小写")
    
    elif "类型错误" in error_type:
        suggestions.append("检查函数参数类型是否匹配")
        suggestions.append("检查是否需要类型转换")
    
    elif "缺少头文件" in error_type:
        suggestions.append("检查 #include 路径是否正确")
        suggestions.append("确认头文件是否存在")
    
    elif "链接错误" in error_type:
        suggestions.append("检查 CMakeLists.txt 中的 target_link_libraries")
        suggestions.append("确认库是否已正确安装")
    
    return suggestions
```

### Step 6: 处理构建失败

如果构建失败，提供选项：

```markdown
❌ 构建失败

错误类型: {error_type}
耗时: {duration}s

错误信息:
  {error_1}
  {error_2}
  ...

修复建议:
1. {suggestion_1}
2. {suggestion_2}

请选择:
1. 手动修复后重试构建 (输入 "1")
2. 回退到上一轮代码 (输入 "2")
3. 查看完整构建日志 (输入 "3")
4. 退出优化 (输入 "4")
```

### Step 7: 记录构建结果

```python
build_result = {
    "iteration_id": iteration_id,
    "timestamp": datetime.now().isoformat(),
    "success": exit_code == 0,
    "duration_sec": duration,
    "exit_code": exit_code,
    "log_file": f"iterations/iter_{iteration_id:03d}/build.log",
    "error_type": error_type if exit_code != 0 else None,
    "error_count": len(errors) if exit_code != 0 else 0
}

# 保存到 iteration-log.json
update_iteration_log(build_result)
```

### Step 8: 构建成功输出

```markdown
✅ 构建成功

耗时: {duration}s
可执行文件: {executable_path}

是否继续运行？(Y/n)
```

## 错误处理

**CMake 配置失败**：
```
❌ CMake 配置失败

错误: Could not find package XXX

诊断: 缺少依赖库

解决方案:
1. 安装缺少的依赖: sudo apt install libxxx-dev
2. 或更新 CMakeLists.txt 中的 find_package
3. 检查 CMAKE_PREFIX_PATH 是否正确
```

**编译错误**：
```
❌ 编译错误

文件: tracker.cpp:123
错误: 'undeclared identifier'

诊断: 代码修改引入语法错误

解决方案:
1. 检查 tracker.cpp:123 的修改
2. 确认变量/函数已正确声明
3. 检查拼写错误
```

**链接错误**：
```
❌ 链接错误

错误: undefined reference to 'XXX'

诊断: 缺少库链接

解决方案:
1. 检查 CMakeLists.txt 中的 target_link_libraries
2. 确认库已正确安装
3. 运行 ldconfig 更新库缓存
```

**构建超时**：
```
⚠️ 构建超时

耗时: > 600s

可能原因:
1. 首次构建（需要编译所有文件）
2. 增量构建触发大量重编译
3. 系统资源不足

建议:
1. 等待构建完成
2. 或终止构建，检查是否有无限循环
```

## 注意事项

1. **增量构建**：优先使用增量构建，避免每次全量编译
2. **并行编译**：使用 `-j4` 或 `-j$(nproc)` 加速编译
3. **构建缓存**：考虑使用 ccache 加速重复编译
4. **错误收集**：收集前 5 个错误，避免日志过长
5. **用户友好**：错误信息要清晰，提供可操作的建议
6. **日志保存**：完整构建日志保存到文件，便于调试
