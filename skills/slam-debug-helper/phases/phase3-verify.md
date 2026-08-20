# Phase 3: 修复方案

## 目标

基于根因诊断结果，给出可操作的修复方案，并说明如何验证修复是否有效。

## 触发词

- "给出修复方案"
- "怎么修复"

## 依赖

Phase 2 的根因诊断结果

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| root_cause | string | ✅ | Phase 2 确定的根因 |
| confidence | string | ✅ | 根因的置信度（高/中/低） |

## 输出产物

```
{project}/.specs/debug/{timestamp}_{session_id}/
├── debug-report.md              # 诊断报告
└── fix-suggestions.md           # 修复方案
```

## 执行步骤

### Step 1: 生成修复方案

根据根因，生成具体的修复步骤。

**核心原则**：修复方案必须是**可操作的**，不能是泛泛的建议。

#### 1.1 修复方案格式

每个修复方案包含：

```markdown
### 修复方案 {N}: {方案名称}

**针对根因**: {根因描述}
**置信度**: {高/中/低}
**难度**: {简单/中等/困难}
**风险**: {低/中/高}

#### 修改内容

**文件**: `{file_path}`
**位置**: 第 {line_number} 行（或 {function_name} 函数）

**修改前**:
```{language}
{original_code}
```

**修改后**:
```{language}
{modified_code}
```

**修改说明**:
- {说明1}
- {说明2}

#### 参数调整（如果有）

**文件**: `{config_file_path}`

**修改前**:
```yaml
parameter_name: {old_value}
```

**修改后**:
```yaml
parameter_name: {new_value}
```

**调整说明**:
- {说明1}
- 推荐范围: {range}
- 建议值: {recommended_value}

#### 验证步骤

1. **重新编译**（如果需要）:
   ```bash
   cd {project}
   mkdir build && cd build
   cmake .. && make -j4
   ```

2. **重新运行系统**:
   ```bash
   {run_command}
   ```

3. **运行评估**:
   ```bash
   {eval_command}
   ```

4. **检查指标**:
   - {指标1}: 应该从 {old_value} 改善到 {expected_value}
   - {指标2}: 应该从 {old_value} 改善到 {expected_value}

5. **验证标准**:
   - ✅ 成功: {成功条件}
   - ❌ 失败: {失败条件}
```

#### 1.2 常见根因的修复方案模板

**根因: 外参平移单位错误（mm vs m）**

```markdown
### 修复方案: 修正外参平移单位

**针对根因**: 外参平移使用了毫米（mm），但系统期望米（m）

**修改内容**:

**文件**: `config/extrinsic.yaml`

**修改前**:
```yaml
T_cam_imu:
  translation: [50.0, 20.0, -10.0]  # 单位: mm
```

**修改后**:
```yaml
T_cam_imim:
  translation: [0.05, 0.02, -0.01]  # 单位: m
```

**验证步骤**:
1. 重新运行系统
2. 检查轨迹是否正常（不发散）
3. 运行评估，ATE RMSE 应该 < 0.1m
```

**根因: IMU 噪声参数过大**

```markdown
### 修复方案: 调整 IMU 噪声参数

**针对根因**: IMU 陀螺仪噪声参数设置过大，导致系统过于依赖视觉

**参数调整**:

**文件**: `config/imu_params.yaml`

**修改前**:
```yaml
gyroscope_noise: 0.01  # rad/s/sqrt(Hz)
accelerometer_noise: 0.1  # m/s^2/sqrt(Hz)
```

**修改后**:
```yaml
gyroscope_noise: 0.001  # rad/s/sqrt(Hz)
accelerometer_noise: 0.01  # m/s^2/sqrt(Hz)
```

**调整说明**:
- 推荐范围: gyro_noise [1e-4, 1e-2], accel_noise [1e-3, 1e-1]
- 建议值基于 IMU 型号（如 BMI088: gyro=1.7e-4, accel=2e-3）

**验证步骤**:
1. 重新运行系统
2. 检查轨迹漂移是否改善
3. 运行评估，ATE RMSE 应该降低 30%+
```

### Step 2: 排序修复方案

如果有多个修复方案，按以下优先级排序：

1. **置信度高 + 难度低** → 最优先尝试
2. **置信度高 + 难度中** → 次优先
3. **置信度中 + 难度低** → 可快速验证
4. **置信度低** → 最后尝试（可能是错误方向）

### Step 3: 生成诊断报告

套用 `templates/debug-report-template.md`，生成完整的诊断报告。

### Step 4: 输出修复建议

```markdown
✅ **修复方案已生成**

### 推荐修复方案（按优先级）

| 优先级 | 方案 | 针对根因 | 置信度 | 难度 |
|--------|------|---------|--------|------|
| 1 | {方案1} | {根因1} | {高} | {简单} |
| 2 | {方案2} | {根因2} | {中} | {中等} |
| 3 | {方案3} | {根因3} | {低} | {困难} |

### 建议执行顺序

1. **先尝试方案 1**:
   - 修改 {file1}
   - 重新运行并评估
   - 预期改善: {expected_improvement}

2. **如果方案 1 无效，尝试方案 2**:
   - 修改 {file2}
   - 重新运行并评估
   - 预期改善: {expected_improvement}

3. **如果所有方案都无效**:
   - 添加调试日志: {具体位置和内容}
   - 重新收集日志
   - 再次运行 debug-helper

### 输出文件

- 诊断报告: `{project}/.specs/debug/{timestamp}/debug-report.md`
- 修复方案: `{project}/.specs/debug/{timestamp}/fix-suggestions.md`
```

## 注意事项

1. **可操作**：每个修复方案必须包含具体的文件、位置、修改内容
2. **验证方法**：必须说明如何验证修复是否有效
3. **风险评估**：标注修复的风险级别（是否可能引入新问题）
4. **回退方案**：如果修复失败，如何回退到修改前状态
5. **参数范围**：参数调整必须给出推荐范围和合理值
