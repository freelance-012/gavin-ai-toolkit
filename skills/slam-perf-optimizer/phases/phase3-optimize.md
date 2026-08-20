# Phase 3: 迭代优化

## 目标

编排评估、日志分析、诊断、修复的迭代循环，持续改进系统性能。

## 触发词

- "开始优化"
- "start optimization"
- "迭代优化"

## 依赖

Phase 2 运行成功

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| config | json | ✅ | Phase 0 的优化配置 |
| iteration_id | int | ⬜ | 当前迭代编号 |

## 输出产物

- `{session_dir}/iterations/iter_{NNN}/eval-report.md`
- `{session_dir}/iterations/iter_{NNN}/log-analysis.md`
- `{session_dir}/iterations/iter_{NNN}/debug-report.md`
- `{session_dir}/iterations/iter_{NNN}/changes.json`

## 执行步骤

### Step 1: 评估当前性能

```python
# 调用 slam-eval-runner
eval_runner = load_skill("slam-eval-runner")

eval_result = eval_runner.run(
    project_path=config["project_path"],
    trajectory_file=f"{session_dir}/iterations/iter_{iteration_id:03d}/trajectory.txt",
    gt_file=config["eval_config"]["gt_file"],
    eval_script=config["eval_config"]["eval_script"]
)

# 提取关键指标
metrics = {
    "ate_rmse": eval_result["ate_rmse"],
    "ate_max": eval_result["ate_max"],
    "rpe_rmse": eval_result["rpe_rmse"]
}

log(f"📊 评估结果:")
log(f"  ATE RMSE: {metrics['ate_rmse']:.4f} m")
log(f"  ATE Max:  {metrics['ate_max']:.4f} m")
log(f"  RPE RMSE: {metrics['rpe_rmse']:.4f} m/m")

# 检查是否达到目标
target = parse_target_metric(config["target_metric"])
if check_target(metrics, target):
    log(f"✅ 达到目标: {config['target_metric']}")
    return "converged"
```

### Step 2: 分析日志

```python
# 调用 slam-log-analyzer
log_analyzer = load_skill("slam-log-analyzer")

# 如果有异常区间，分析该区间
anomaly_periods = eval_result.get("anomaly_periods", [])

if anomaly_periods:
    # 分析最严重的异常区间
    worst_period = max(anomaly_periods, key=lambda p: p["max_error"])
    
    log(f"\n🔍 发现异常区间:")
    log(f"  时间: {worst_period['start']:.2f} - {worst_period['end']:.2f}s")
    log(f"  最大误差: {worst_period['max_error']:.4f}m")
    
    # 分析该区间
    log_analysis = log_analyzer.analyze_time_range(
        project_path=config["project_path"],
        log_file=f"{session_dir}/iterations/iter_{iteration_id:03d}/run.log",
        start_time=worst_period["start"],
        end_time=worst_period["end"]
    )
else:
    # 分析整个运行过程
    log_analysis = log_analyzer.analyze_full(
        project_path=config["project_path"],
        log_file=f"{session_dir}/iterations/iter_{iteration_id:03d}/run.log"
    )

# 提取关键问题
issues = log_analysis.get("issues", [])
log(f"\n🔍 检测到 {len(issues)} 个问题:")
for issue in issues:
    log(f"  - {issue['description']}")
```

### Step 3: 诊断根因

```python
# 调用 slam-debug-helper
debug_helper = load_skill("slam-debug-helper")

# 准备诊断输入
diagnosis_input = {
    "metrics": metrics,
    "issues": issues,
    "log_analysis": log_analysis,
    "eval_result": eval_result
}

# 运行诊断
debug_result = debug_helper.diagnose(
    project_path=config["project_path"],
    input_data=diagnosis_input
)

# 提取根因和修复建议
root_causes = debug_result.get("root_causes", [])
fixes = debug_result.get("fixes", [])

log(f"\n🔬 诊断结果:")
for i, cause in enumerate(root_causes, 1):
    log(f"  {i}. {cause['description']} (置信度: {cause['confidence']})")
```

### Step 4: 生成修复方案

```python
if not fixes:
    log("\n⚠️ 未找到可操作的修复建议")
    return "no_fix"

log(f"\n💡 修复建议:")
for i, fix in enumerate(fixes, 1):
    log(f"\n  修复 {i}:")
    log(f"    类型: {fix['type']}")
    log(f"    文件: {fix['file']}")
    log(f"    描述: {fix['description']}")
    
    if fix["type"] == "parameter":
        log(f"    修改: {fix['before']} → {fix['after']}")
    elif fix["type"] == "code":
        log(f"    位置: 行 {fix['line']}")
```

### Step 5: 应用修复

```python
changes = []

for fix in fixes:
    # 显示修复详情
    log(f"\n🔧 准备应用修复: {fix['description']}")
    
    # 根据 auto_apply 设置决定是否自动应用
    if config.get("auto_apply", False):
        apply = True
        log(f"  自动应用 (auto_apply=true)")
    else:
        # 询问用户
        log(f"\n是否应用此修复？(Y/n/q)")
        log(f"  Y: 应用并继续")
        log(f"  n: 跳过此修复")
        log(f"  q: 退出优化循环")
        
        user_input = input().strip().lower()
        
        if user_input == "q":
            return "user_abort"
        elif user_input == "n":
            log(f"  ⏭️ 跳过修复")
            continue
        else:
            apply = True
    
    if apply:
        # 应用修复
        try:
            apply_fix(fix, project_path)
            changes.append(fix)
            log(f"  ✅ 已应用")
        except Exception as e:
            log(f"  ❌ 应用失败: {e}")
            log(f"  建议: 手动修复或回退")
```

### Step 6: 记录本轮改动

```python
iteration_changes = {
    "iteration_id": iteration_id,
    "timestamp": datetime.now().isoformat(),
    "metrics_before": metrics_before,
    "metrics_after": metrics,
    "changes": changes,
    "issues": issues,
    "root_causes": root_causes
}

# 保存到 changes.json
changes_file = f"{session_dir}/iterations/iter_{iteration_id:03d}/changes.json"
with open(changes_file, "w") as f:
    json.dump(iteration_changes, f, indent=2)

# 更新 iteration-log.json
update_iteration_log(iteration_changes)
```

### Step 7: 检查收敛

```python
# 检查是否应该继续迭代
should_continue, reason = check_convergence(
    iteration_log=config["iteration_log"],
    max_iterations=config["max_iterations"],
    target_metric=config["target_metric"]
)

if not should_continue:
    log(f"\n⏹️ 停止迭代: {reason}")
    return reason

# 准备下一轮迭代
log(f"\n🔄 准备第 {iteration_id + 1} 轮迭代...")
log(f"  当前指标: ate_rmse = {metrics['ate_rmse']:.4f}")
log(f"  目标: {config['target_metric']}")

return "continue"
```

### Step 8: 收敛检查逻辑

```python
def check_convergence(iteration_log, max_iterations, target_metric):
    """
    检查是否应该继续迭代
    """
    current_iter = len(iteration_log["iterations"])
    
    # 1. 达到最大迭代次数
    if current_iter >= max_iterations:
        return False, f"达到最大迭代次数 ({max_iterations})"
    
    # 2. 检查是否达到目标
    latest_metrics = iteration_log["iterations"][-1]["metrics"]
    if check_target(latest_metrics, target_metric):
        return False, "达到目标指标"
    
    # 3. 检查性能是否不再提升
    if current_iter >= 3:
        recent_improvements = []
        for i in range(-3, 0):
            prev = iteration_log["iterations"][i-1]["metrics"]["ate_rmse"]
            curr = iteration_log["iterations"][i]["metrics"]["ate_rmse"]
            improvement = (prev - curr) / prev * 100
            recent_improvements.append(improvement)
        
        avg_improvement = sum(recent_improvements) / len(recent_improvements)
        if avg_improvement < 1.0:  # 平均改进 < 1%
            return False, f"连续 3 轮改进 < 1% (平均 {avg_improvement:.2f}%)"
    
    # 4. 检查性能是否恶化
    if current_iter >= 2:
        prev = iteration_log["iterations"][-2]["metrics"]["ate_rmse"]
        curr = iteration_log["iterations"][-1]["metrics"]["ate_rmse"]
        degradation = (curr - prev) / prev * 100
        
        if degradation > 10:  # 恶化 > 10%
            return False, f"性能恶化 {degradation:.1f}%，建议回退"
    
    return True, "继续迭代"

def check_target(metrics, target_str):
    """
    检查是否达到目标指标
    例如: "ate_rmse < 0.1"
    """
    import re
    match = re.match(r"(\w+)\s*([<>=]+)\s*([\d.]+)", target_str)
    if not match:
        return False
    
    metric_name, operator, target_value = match.groups()
    target_value = float(target_value)
    
    if metric_name not in metrics:
        return False
    
    actual_value = metrics[metric_name]
    
    if operator == "<":
        return actual_value < target_value
    elif operator == "<=":
        return actual_value <= target_value
    elif operator == ">":
        return actual_value > target_value
    elif operator == ">=":
        return actual_value >= target_value
    elif operator == "==":
        return abs(actual_value - target_value) < 1e-6
    
    return False
```

### Step 9: 应用修复的实现

```python
def apply_fix(fix, project_path):
    """
    应用修复到代码或配置
    """
    if fix["type"] == "parameter":
        # 修改参数文件
        apply_parameter_fix(fix, project_path)
    
    elif fix["type"] == "code":
        # 修改代码文件
        apply_code_fix(fix, project_path)
    
    else:
        raise ValueError(f"不支持的修复类型: {fix['type']}")

def apply_parameter_fix(fix, project_path):
    """
    修改参数文件
    """
    file_path = os.path.join(project_path, fix["file"])
    
    with open(file_path, "r") as f:
        content = f.read()
    
    # 替换参数值
    old_line = fix["before"]
    new_line = fix["after"]
    
    if old_line not in content:
        raise ValueError(f"未找到要修改的行: {old_line}")
    
    content = content.replace(old_line, new_line)
    
    with open(file_path, "w") as f:
        f.write(content)

def apply_code_fix(fix, project_path):
    """
    修改代码文件
    """
    file_path = os.path.join(project_path, fix["file"])
    
    with open(file_path, "r") as f:
        lines = f.readlines()
    
    # 修改指定行
    line_idx = fix["line"] - 1
    if line_idx >= len(lines):
        raise ValueError(f"行号超出范围: {fix['line']}")
    
    lines[line_idx] = fix["new_code"] + "\n"
    
    with open(file_path, "w") as f:
        f.writelines(lines)
```

## 错误处理

**评估失败**：
```
❌ 评估失败

错误: 轨迹文件不存在

诊断: 运行未生成轨迹文件

建议:
1. 检查运行日志
2. 确认输出路径配置
3. 重新运行系统
```

**无修复建议**：
```
⚠️ 未找到可操作的修复建议

可能原因:
1. 问题过于复杂，需要人工分析
2. 日志信息不足
3. 已接近系统性能极限

建议:
1. 手动分析日志和代码
2. 添加更多调试日志
3. 考虑算法层面的改进
```

**修复应用失败**：
```
❌ 修复应用失败

修复: {fix_description}
错误: {error_message}

建议:
1. 手动应用修复
2. 检查文件权限
3. 回退到上一轮
```

## 注意事项

1. **用户确认**：默认每轮修复前需要用户确认
2. **自动模式**：auto_apply=true 时自动应用所有修复
3. **回退机制**：性能恶化时支持回退到上一轮
4. **收敛判断**：多种收敛条件，避免无效迭代
5. **改动记录**：详细记录每轮的改动和效果
6. **错误恢复**：修复应用失败时提供恢复选项
7. **迭代限制**：设置最大迭代次数，防止无限循环
