# SLAM 系统性能优化报告模板

## 使用说明

此模板用于生成 slam-perf-optimizer 的最终优化报告。报告应包含优化目标、过程、结果和建议。

---

# {project_name} 性能优化报告

> **优化时间**: {start_time} - {end_time}  
> **总迭代次数**: {total_iterations}  
> **总耗时**: {total_duration} 秒 ({total_duration_min} 分钟)  
> **优化会话 ID**: {session_id}

---

## 1. 优化目标

- **目标指标**: {target_metric}
- **最大迭代次数**: {max_iterations}
- **自动应用修复**: {auto_apply}
- **初始性能**: {initial_metrics}
- **目标性能**: {target_metrics}

---

## 2. 优化结果

### 2.1 最终性能

| 指标 | 初始值 | 最终值 | 改进 | 改进率 |
|------|--------|--------|------|--------|
| ATE RMSE (m) | {initial_ate_rmse} | {final_ate_rmse} | {ate_rmse_diff} | {ate_rmse_improvement}% |
| ATE Max (m) | {initial_ate_max} | {final_ate_max} | {ate_max_diff} | {ate_max_improvement}% |
| RPE RMSE (m/m) | {initial_rpe_rmse} | {final_rpe_rmse} | {rpe_rmse_diff} | {rpe_rmse_improvement}% |

### 2.2 收敛状态

{convergence_status}

**判断依据**: {convergence_reason}

### 2.3 目标达成

{target_achievement}

---

## 3. 迭代历史

### 3.1 性能演进

| 迭代 | ATE RMSE (m) | 改进率 | 主要改动 | 状态 |
|------|--------------|--------|---------|------|
{iteration_history_table}

### 3.2 关键改动统计

**总改动次数**: {total_changes}

**改动类型分布**:
- 参数调整: {param_changes} 次
- 代码修改: {code_changes} 次
- 配置变更: {config_changes} 次

### 3.3 最有效的改动

{most_effective_changes}

---

## 4. 详细改动记录

### 4.1 参数调整

{parameter_changes_table}

### 4.2 代码修改

{code_changes_table}

### 4.3 配置变更

{config_changes_table}

---

## 5. 问题分析

### 5.1 检测到的问题

{detected_issues_list}

### 5.2 根因分析

{root_cause_analysis}

### 5.3 问题解决情况

{issue_resolution}

---

## 6. 优化建议

### 6.1 短期改进

{short_term_suggestions}

### 6.2 长期优化方向

{long_term_suggestions}

### 6.3 注意事项

{cautions}

---

## 7. 附录

### 7.1 优化配置

```json
{optimization_config_json}
```

### 7.2 相关文件

- **优化配置**: `{session_dir}/optimization-config.json`
- **迭代日志**: `{session_dir}/iteration-log.json`
- **迭代数据**: `{session_dir}/iterations/`
  - 第 1 轮: `iter_001/`
  - 第 2 轮: `iter_002/`
  - ...

### 7.3 生成信息

- **报告生成时间**: {generation_time}
- **优化 Skill**: slam-perf-optimizer v1.0
- **依赖 Skills**: 
  - slam-eval-runner
  - slam-log-analyzer
  - slam-debug-helper

---

## 8. 总结

{final_summary}

---

**报告生成者**: slam-perf-optimizer  
**报告版本**: v1.0  
**生成时间**: {generation_time}
