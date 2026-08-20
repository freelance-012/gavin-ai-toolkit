# Phase 1: 运行评估

## 目标

执行用户定义的评估脚本，收集评估输出（指标数值、误差时序数据）。

## 触发词

- "运行评估"
- "执行评估脚本"

## 依赖

Phase 0 的配置信息

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| eval_command | string | ✅ | Phase 0 生成的完整评估命令 |
| output_dir | string | ✅ | 评估结果输出目录 |

## 输出产物

```
{output_dir}/
├── eval-stdout.txt        # 评估脚本的标准输出
├── eval-stderr.txt        # 评估脚本的标准错误
└── eval-exit-code.txt     # 退出码
```

## 执行步骤

### Step 1: 创建输出目录

```bash
mkdir -p {output_dir}
```

### Step 2: 运行评估脚本

执行 Phase 0 生成的评估命令，捕获输出：

```bash
# 执行评估命令，分别捕获 stdout 和 stderr
{eval_command} > {output_dir}/eval-stdout.txt 2> {output_dir}/eval-stderr.txt
echo $? > {output_dir}/eval-exit-code.txt
```

**超时设置**：
- 默认超时：300 秒（5 分钟）
- 如果评估脚本运行时间较长，提示用户

### Step 3: 检查执行结果

读取退出码：

```bash
exit_code=$(cat {output_dir}/eval-exit-code.txt)
```

**退出码判断**：
- `0`：成功
- 非 `0`：失败，读取 stderr 分析错误原因

### Step 4: 解析评估输出

根据 spec 中定义的输出格式，解析 stdout 内容。

**常见输出格式**：

#### 格式 1：直接输出指标
```
ATE RMSE: 0.0523 m
ATE Mean: 0.0412 m
ATE Max: 0.1234 m
RPE RMSE: 0.0123 m/m
```

#### 格式 2：表格形式
```
==================================
   Trajectory Evaluation Results
==================================
Metric          Value       Unit
----------------------------------
ATE RMSE        0.0523      m
ATE Mean        0.0412      m
ATE Max         0.1234      m
RPE RMSE        0.0123      m/m
==================================
```

#### 格式 3：JSON 形式
```json
{
  "ate_rmse": 0.0523,
  "ate_mean": 0.0412,
  "ate_max": 0.1234,
  "rpe_rmse": 0.0123
}
```

**解析策略**：
1. 先尝试匹配 spec 中描述的格式
2. 如果无法匹配，尝试通用模式（数字 + 单位）
3. 如果仍无法解析，输出原始内容供用户手动确认

### Step 5: 提取误差时序数据（如果有）

某些评估脚本会输出每个时刻的误差，例如：

```
timestamp   error   error_x   error_y   error_z
1623456789.123   0.052   0.031   0.022   0.041
1623456789.223   0.054   0.033   0.024   0.042
...
```

如果评估脚本输出时序数据：
1. 提取并保存到 `{output_dir}/error-timeseries.csv`
2. 确保包含 timestamp 和 error 列

如果评估脚本不输出时序数据：
- 标注"评估脚本未提供时序数据"
- Phase 2 将跳过时序分析

### Step 6: 汇总输出

```markdown
✅ 评估执行完成

### 执行信息
- 命令: {command}
- 退出码: {exit_code}
- 运行时间: {duration}

### 评估结果
| 指标 | 值 | 单位 | 合格阈值 | 状态 |
|------|-----|------|---------|------|
| {metric1} | {value1} | {unit1} | {threshold1} | ✅/❌ |
| ... | ... | ... | ... | ... |

### 时序数据
- 状态: ✅ 已提取 / ❌ 评估脚本未提供
- 数据点数: {N}
- 时间范围: {t_start} ~ {t_end}

输出文件:
- {output_dir}/eval-stdout.txt
- {output_dir}/eval-stderr.txt
- {output_dir}/error-timeseries.csv（如果有）
```

## 注意事项

1. **不修改评估脚本**：只执行用户定义的脚本，不修改脚本内容
2. **错误处理**：如果脚本执行失败，输出完整错误信息供用户诊断
3. **格式兼容**：尽可能兼容不同的输出格式，无法解析时保留原始输出
4. **时序数据可选**：不是所有评估脚本都输出时序数据，缺失时标注但不阻塞
