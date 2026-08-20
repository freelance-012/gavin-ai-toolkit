# 日志分析报告模板

## 基本信息

- **项目路径**: {project_path}
- **日志文件**: {log_file}
- **分析时间**: {analysis_time}
- **分析时间段**: {time_range_start} - {time_range_end} ({duration} 秒)
- **日志条目数**: {log_count}

---

## 日志概览

### 时间范围
- **起始时间**: {start_timestamp}
- **结束时间**: {end_timestamp}
- **持续时间**: {duration} 秒
- **日志密度**: {density} 条/秒

### 日志级别分布
| 级别 | 数量 | 占比 |
|------|------|------|
| DEBUG | {debug_count} | {debug_percent}% |
| INFO | {info_count} | {info_percent}% |
| WARN | {warn_count} | {warn_percent}% |
| ERROR | {error_count} | {error_percent}% |

### 模块分布
| 模块 | 日志数量 | 占比 |
|------|---------|------|
| {module1} | {count1} | {percent1}% |
| {module2} | {count2} | {percent2}% |
| {module3} | {count3} | {percent3}% |

---

## 关键指标统计

### 特征跟踪
| 指标 | 平均值 | 标准差 | 最小值 | 最大值 | 采样数 |
|------|--------|--------|--------|--------|--------|
| 特征数 | {feature_mean} | {feature_std} | {feature_min} | {feature_max} | {feature_count} |
| 内点数 | {inlier_mean} | {inlier_std} | {inlier_min} | {inlier_max} | {inlier_count} |
| 外点数 | {outlier_mean} | {outlier_std} | {outlier_min} | {outlier_max} | {outlier_count} |
| 内点比例 | {ratio_mean}% | {ratio_std}% | {ratio_min}% | {ratio_max}% | {ratio_count} |

### 优化性能
| 指标 | 平均值 | 标准差 | 最小值 | 最大值 | 采样数 |
|------|--------|--------|--------|--------|--------|
| 迭代次数 | {iter_mean} | {iter_std} | {iter_min} | {iter_max} | {iter_count} |
| 优化代价 | {cost_mean} | {cost_std} | {cost_min} | {cost_max} | {cost_count} |
| 是否收敛 | {converge_rate}% | - | - | - | {converge_count} |

### 处理性能
| 指标 | 平均值 | 标准差 | 最小值 | 最大值 | 采样数 |
|------|--------|--------|--------|--------|--------|
| 处理时间 | {time_mean} ms | {time_std} ms | {time_min} ms | {time_max} ms | {time_count} |
| 帧率 | {fps_mean} FPS | {fps_std} FPS | {fps_min} FPS | {fps_max} FPS | {fps_count} |

---

## 关键事件

### 高严重度事件
| 时间戳 | 模块 | 事件类型 | 消息内容 | 代码位置 |
|--------|------|---------|---------|---------|
| {timestamp1} | {module1} | {type1} | {message1} | {location1} |
| {timestamp2} | {module2} | {type2} | {message2} | {location2} |

### 中等严重度事件
| 时间戳 | 模块 | 事件类型 | 消息内容 | 代码位置 |
|--------|------|---------|---------|---------|
| {timestamp1} | {module1} | {type1} | {message1} | {location1} |
| {timestamp2} | {module2} | {type2} | {message2} | {location2} |

### 低严重度事件
| 时间戳 | 模块 | 事件类型 | 消息内容 | 代码位置 |
|--------|------|---------|---------|---------|
| {timestamp1} | {module1} | {type1} | {message1} | {location1} |
| {timestamp2} | {module2} | {type2} | {message2} | {location2} |

---

## 异常模式

### 模式 1: {pattern_name}
- **时间范围**: {start_time} - {end_time}
- **持续时间**: {duration} 秒
- **描述**: {description}
- **相关指标**:
  - {metric1}: {value1} → {value2} ({change}%)
  - {metric2}: {value1} → {value2} ({change}%)
- **可能原因**:
  - {cause1}
  - {cause2}
- **相关代码**:
  - {file1}:{line1} - {function1}
  - {file2}:{line2} - {function2}

### 模式 2: {pattern_name}
- **时间范围**: {start_time} - {end_time}
- **持续时间**: {duration} 秒
- **描述**: {description}
- **相关指标**:
  - {metric1}: {value1} → {value2} ({change}%)
- **可能原因**:
  - {cause1}
- **相关代码**:
  - {file1}:{line1} - {function1}

---

## 代码映射统计

### 映射覆盖率
- **总日志条目**: {total_entries}
- **成功映射**: {mapped_entries} ({mapped_percent}%)
- **未映射**: {unmapped_entries} ({unmapped_percent}%)

### 模块映射覆盖率
| 模块 | 总日志数 | 已映射 | 覆盖率 |
|------|---------|--------|--------|
| {module1} | {total1} | {mapped1} | {coverage1}% |
| {module2} | {total2} | {mapped2} | {coverage2}% |
| {module3} | {total3} | {mapped3} | {coverage3}% |

### 关键映射
| 日志模式 | 出现次数 | 代码位置 | 函数 |
|---------|---------|---------|------|
| {pattern1} | {count1} | {location1} | {function1} |
| {pattern2} | {count2} | {location2} | {function2} |
| {pattern3} | {count3} | {location3} | {function3} |

---

## 对比分析

### 与正常时段对比

| 指标 | 正常时段 | 当前时段 | 变化 | 变化率 |
|------|---------|---------|------|--------|
| 特征数 | {normal_feature} | {current_feature} | {diff_feature} | {change_feature}% |
| 内点数 | {normal_inlier} | {current_inlier} | {diff_inlier} | {change_inlier}% |
| 迭代次数 | {normal_iter} | {current_iter} | {diff_iter} | {change_iter}% |
| 处理时间 | {normal_time} ms | {current_time} ms | {diff_time} ms | {change_time}% |
| 帧率 | {normal_fps} FPS | {current_fps} FPS | {diff_fps} FPS | {change_fps}% |

---

## 诊断结论

### 主要问题

1. **问题 1**: {problem_description}
   - **严重程度**: {severity}
   - **影响范围**: {impact}
   - **证据**: {evidence}
   - **相关代码**: {code_location}

2. **问题 2**: {problem_description}
   - **严重程度**: {severity}
   - **影响范围**: {impact}
   - **证据**: {evidence}
   - **相关代码**: {code_location}

### 根本原因分析

基于日志分析，识别出以下根本原因：

1. **原因 1**: {root_cause}
   - **置信度**: {confidence}%
   - **支持证据**:
     - {evidence1}
     - {evidence2}
   - **相关代码**: {code_location}

2. **原因 2**: {root_cause}
   - **置信度**: {confidence}%
   - **支持证据**:
     - {evidence1}
   - **相关代码**: {code_location}

---

## 建议

### 立即行动

1. **行动 1**: {action_description}
   - **优先级**: {priority}
   - **预期效果**: {expected_effect}
   - **相关代码**: {code_location}

2. **行动 2**: {action_description}
   - **优先级**: {priority}
   - **预期效果**: {expected_effect}
   - **相关代码**: {code_location}

### 代码插桩建议

为了进一步诊断问题，建议在以下位置添加调试日志：

1. **插桩点 1**: {file}:{line}
   - **原因**: {reason}
   - **建议记录**: {variables}
   - **优先级**: {priority}

2. **插桩点 2**: {file}:{line}
   - **原因**: {reason}
   - **建议记录**: {variables}
   - **优先级**: {priority}

### 进一步分析

1. **分析 1**: {analysis_description}
   - **目的**: {purpose}
   - **方法**: {method}

2. **分析 2**: {analysis_description}
   - **目的**: {purpose}
   - **方法**: {method}

### 长期优化

1. **优化 1**: {optimization_description}
   - **预期收益**: {benefit}
   - **实施难度**: {difficulty}

2. **优化 2**: {optimization_description}
   - **预期收益**: {benefit}
   - **实施难度**: {difficulty}

---

## 附录

### A. 日志样本

**时间段**: {sample_start} - {sample_end}

```
{log_sample}
```

### B. 相关代码片段

**文件**: {file}
**函数**: {function}
**行号**: {line}

```cpp
{code_snippet}
```

### C. 分析参数

- **日志格式**: {log_format}
- **时间戳格式**: {timestamp_format}
- **异常阈值**: {anomaly_threshold}
- **关键指标**: {key_metrics}

### D. 工具版本

- **slam-log-analyzer**: {version}
- **分析时间**: {analysis_duration}
- **Python 版本**: {python_version}

---

## 参考

- 项目规格: `{project_path}/.specs/project-spec.md`
- 评估结果: `{project_path}/.specs/eval-results/{eval_id}/eval-report.md`
- 代码映射: `{project_path}/.specs/log-analysis/{analysis_id}/code-log-mapping.json`
- 插桩计划: `{project_path}/.specs/log-analysis/{analysis_id}/instrument-plan.json`
