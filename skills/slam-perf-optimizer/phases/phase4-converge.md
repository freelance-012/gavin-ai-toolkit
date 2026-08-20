# Phase 4: 收敛判断

## 目标

判断优化是否收敛，生成最终优化报告，总结优化过程和结果。

## 触发词

- "生成优化报告"
- "generate report"
- "完成优化"

## 依赖

Phase 3 迭代优化完成

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| config | json | ✅ | Phase 0 的优化配置 |
| iteration_log | json | ✅ | 所有迭代的日志 |

## 输出产物

- `{session_dir}/optimization-report.md`

## 执行步骤

### Step 1: 汇总优化结果

```python
iterations = config["iteration_log"]["iterations"]
total_iterations = len(iterations)

# 提取初始和最终指标
initial_metrics = iterations[0]["metrics"]
final_metrics = iterations[-1]["metrics"]

# 计算改进
improvements = {}
for key in initial_metrics:
    initial = initial_metrics[key]
    final = final_metrics[key]
    improvement = (initial - final) / initial * 100
    improvements[key] = {
        "initial": initial,
        "final": final,
        "improvement": improvement,
        "improvement_pct": f"{improvement:.1f}%"
    }

# 计算总耗时
total_duration = sum(iter["duration_sec"] for iter in iterations)
```

### Step 2: 判断收敛状态

```python
def determine_convergence_status(iteration_log, config):
    """
    判断优化收敛状态
    """
    iterations = iteration_log["iterations"]
    final_metrics = iterations[-1]["metrics"]
    
    # 1. 达到目标
    target = config["target_metric"]
    if check_target(final_metrics, target):
        return "converged", "✅ 达到目标指标"
    
    # 2. 达到最大迭代次数
    if len(iterations) >= config["max_iterations"]:
        return "max_iterations", f"⚠️ 达到最大迭代次数 ({config['max_iterations']})"
    
    # 3. 性能不再提升
    if len(iterations) >= 3:
        recent_improvements = []
        for i in range(-3, 0):
            prev = iterations[i-1]["metrics"]["ate_rmse"]
            curr = iterations[i]["metrics"]["ate_rmse"]
            improvement = (prev - curr) / prev * 100
            recent_improvements.append(improvement)
        
        avg_improvement = sum(recent_improvements) / len(recent_improvements)
        if avg_improvement < 1.0:
            return "plateau", f"⚠️ 性能趋于稳定 (平均改进 {avg_improvement:.2f}%)"
    
    # 4. 用户中止
    last_iter = iterations[-1]
    if last_iter.get("status") == "user_abort":
        return "user_abort", "⏹️ 用户中止优化"
    
    # 5. 构建/运行失败
    if last_iter.get("status") in ["build_failed", "run_failed"]:
        return "failed", "❌ 构建或运行失败"
    
    return "unknown", "未知状态"

status, status_message = determine_convergence_status(config["iteration_log"], config)
```

### Step 3: 分析优化过程

```python
# 提取每轮的改动
all_changes = []
for iter_data in iterations:
    changes = iter_data.get("changes", [])
    for change in changes:
        all_changes.append({
            "iteration": iter_data["id"],
            "type": change["type"],
            "file": change["file"],
            "description": change["description"]
        })

# 统计改动类型
change_types = {}
for change in all_changes:
    change_type = change["type"]
    change_types[change_type] = change_types.get(change_type, 0) + 1

# 找出最有效的改动
best_iterations = []
for i in range(1, len(iterations)):
    prev_rmse = iterations[i-1]["metrics"]["ate_rmse"]
    curr_rmse = iterations[i]["metrics"]["ate_rmse"]
    improvement = (prev_rmse - curr_rmse) / prev_rmse * 100
    
    if improvement > 5:  # 改进 > 5%
        best_iterations.append({
            "iteration": iterations[i]["id"],
            "improvement": improvement,
            "changes": iterations[i].get("changes", [])
        })

# 按改进幅度排序
best_iterations.sort(key=lambda x: x["improvement"], reverse=True)
```

### Step 4: 生成优化报告

```markdown
# SLAM 系统性能优化报告

> **项目**: {project_name}
> **优化时间**: {start_time} - {end_time}
> **总迭代次数**: {total_iterations}
> **总耗时**: {total_duration:.1f} 秒 ({total_duration/60:.1f} 分钟)

---

## 1. 优化目标

- **目标指标**: {target_metric}
- **最大迭代次数**: {max_iterations}
- **自动应用**: {auto_apply}

---

## 2. 优化结果

### 2.1 收敛状态

{status_message}

### 2.2 性能对比

| 指标 | 初始值 | 最终值 | 改进 | 改进率 |
|------|--------|--------|------|--------|
| ATE RMSE | {initial_ate_rmse:.4f} m | {final_ate_rmse:.4f} m | {ate_diff:.4f} m | {ate_improvement:.1f}% |
| ATE Max | {initial_ate_max:.4f} m | {final_ate_max:.4f} m | {ate_max_diff:.4f} m | {ate_max_improvement:.1f}% |
| RPE RMSE | {initial_rpe_rmse:.4f} m/m | {final_rpe_rmse:.4f} m/m | {rpe_diff:.4f} m/m | {rpe_improvement:.1f}% |

### 2.3 目标达成情况

{if status == "converged"}
✅ **目标达成**

最终指标满足目标要求:
- {target_metric}
- 实际值: {final_value}
{else}
❌ **目标未达成**

最终指标与目标的差距:
- 目标: {target_metric}
- 实际: {final_value}
- 差距: {gap}
{/if}

---

## 3. 迭代历史

### 3.1 性能演进

| 迭代 | ATE RMSE (m) | ATE Max (m) | RPE RMSE (m/m) | 改进率 | 状态 |
|------|--------------|-------------|----------------|--------|------|
| 1 | {iter1_ate_rmse:.4f} | {iter1_ate_max:.4f} | {iter1_rpe_rmse:.4f} | - | 基线 |
| 2 | {iter2_ate_rmse:.4f} | {iter2_ate_max:.4f} | {iter2_rpe_rmse:.4f} | {iter2_improvement:.1f}% | {iter2_status} |
| ... | ... | ... | ... | ... | ... |
| {N} | {iterN_ate_rmse:.4f} | {iterN_ate_max:.4f} | {iterN_rpe_rmse:.4f} | {iterN_improvement:.1f}% | {iterN_status} |

### 3.2 关键改动

共进行 {total_changes} 次改动:

{for change_type, count in change_types.items()}
- **{change_type}**: {count} 次
{/for}

#### 最有效的改动

{for best in best_iterations[:3]}
**第 {best.iteration} 轮** (改进 {best.improvement:.1f}%):
{for change in best.changes}
- {change.type}: {change.description}
{/for}

{/for}

---

## 4. 详细改动记录

### 4.1 参数调整

{parameter_changes = [c for c in all_changes if c.type == "parameter"]}
{if parameter_changes}
| 迭代 | 文件 | 改动描述 |
|------|------|---------|
{for change in parameter_changes}
| {change.iteration} | {change.file} | {change.description} |
{/for}
{else}
无参数调整
{/if}

### 4.2 代码修改

{code_changes = [c for c in all_changes if c.type == "code"]}
{if code_changes}
| 迭代 | 文件 | 改动描述 |
|------|------|---------|
{for change in code_changes}
| {change.iteration} | {change.file} | {change.description} |
{/for}
{else}
无代码修改
{/if}

---

## 5. 问题分析

### 5.1 检测到的问题

{all_issues = []}
{for iter_data in iterations}
{for issue in iter_data.get("issues", [])}
{all_issues.append({"iteration": iter_data.id, "issue": issue})}
{/for}
{/for}

共检测到 {len(all_issues)} 个问题:

{for item in all_issues[:10]}
- **第 {item.iteration} 轮**: {item.issue.description}
{/for}

### 5.2 根因分析

{all_root_causes = []}
{for iter_data in iterations}
{for cause in iter_data.get("root_causes", [])}
{all_root_causes.append({"iteration": iter_data.id, "cause": cause})}
{/for}
{/for}

主要根因:

{for item in all_root_causes[:5]}
- **第 {item.iteration} 轮**: {item.cause.description} (置信度: {item.cause.confidence})
{/for}

---

## 6. 优化建议

### 6.1 短期改进

基于当前优化结果，建议:

{suggestions = []}
{if final_metrics.ate_rmse > target_value * 1.5}
- 继续调整参数，重点关注: {focus_areas}
{suggestions.append("继续参数调优")}
{/if}

{if len(best_iterations) == 0}
- 考虑算法层面的改进
{suggestions.append("算法改进")}
{/if}

{if status == "plateau"}
- 当前可能接近性能极限，建议:
  - 使用更高质量的传感器数据
  - 改进特征提取算法
  - 优化后端优化策略
{suggestions.append("突破性能极限")}
{/if}

### 6.2 长期优化方向

1. **传感器校准**: 确保外参和时间同步精度
2. **参数自动调优**: 使用贝叶斯优化等方法自动搜索最优参数
3. **算法改进**: 考虑引入更先进的 SLAM 算法
4. **硬件升级**: 使用更高精度的传感器

---

## 7. 附录

### 7.1 优化配置

```json
{
  "project": "{project_name}",
  "max_iterations": {max_iterations},
  "target_metric": "{target_metric}",
  "auto_apply": {auto_apply}
}
```

### 7.2 相关文件

- 优化配置: `{session_dir}/optimization-config.json`
- 迭代日志: `{session_dir}/iteration-log.json`
- 各轮详细数据: `{session_dir}/iterations/iter_*/`

### 7.3 生成信息

- 报告生成时间: {generation_time}
- 优化会话 ID: {session_id}
- 优化 Skill: slam-perf-optimizer v1.0

---

## 8. 总结

{if status == "converged"}
✅ **优化成功**

经过 {total_iterations} 轮迭代优化，系统性能显著提升:
- ATE RMSE 从 {initial_ate_rmse:.4f}m 降低到 {final_ate_rmse:.4f}m
- 总体改进 {total_improvement:.1f}%
- 达到目标指标 {target_metric}

主要改进来自:
{for best in best_iterations[:2]}
- 第 {best.iteration} 轮: {best.changes[0].description if best.changes else "参数调整"}
{/for}
{elif status == "max_iterations"}
⚠️ **达到最大迭代次数**

经过 {total_iterations} 轮优化，性能改进 {total_improvement:.1f}%，但未达到目标。

建议:
1. 增加最大迭代次数继续优化
2. 调整优化策略
3. 考虑算法层面的改进
{elif status == "plateau"}
⚠️ **性能趋于稳定**

经过 {total_iterations} 轮优化，性能改进 {total_improvement:.1f}%，最近 3 轮改进 < 1%。

可能已接近当前配置的性能极限，建议:
1. 尝试不同的参数组合
2. 改进算法实现
3. 使用更高质量的数据
{else}
⏹️ **优化中止**

优化在 {total_iterations} 轮后中止: {status_message}

最终性能改进 {total_improvement:.1f}%。
{/if}
```

### Step 5: 保存报告

```python
report_file = f"{session_dir}/optimization-report.md"
with open(report_file, "w") as f:
    f.write(report_content)

log(f"\n✅ 优化报告已生成")
log(f"📄 报告路径: {report_file}")
```

### Step 6: 输出最终摘要

```markdown
🎉 优化完成！

📊 最终结果:
- 总迭代: {total_iterations} 轮
- 总耗时: {total_duration:.1f} 秒
- 初始 ATE RMSE: {initial_ate_rmse:.4f} m
- 最终 ATE RMSE: {final_ate_rmse:.4f} m
- 总体改进: {total_improvement:.1f}%

{status_message}

📄 详细报告: {report_file}
📁 迭代数据: {session_dir}/iterations/

是否查看报告？(Y/n)
```

## 注意事项

1. **报告完整性**：确保报告包含所有关键信息
2. **数据准确性**：仔细核对所有指标和计算
3. **可读性**：使用清晰的表格和格式
4. **可追溯性**：提供所有相关文件的路径
5. **建议实用性**：给出具体可操作的建议
6. **状态判断**：准确判断收敛状态
7. **总结简洁**：提供清晰的最终总结
