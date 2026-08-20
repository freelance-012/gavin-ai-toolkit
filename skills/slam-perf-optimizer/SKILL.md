# slam-perf-optimizer

SLAM 系统性能优化编排器。自动化"构建 → 运行 → 评估 → 分析 → 诊断 → 修复 → 再运行"的迭代优化循环。

## 定位

**编排 skill**——不直接执行评估、分析、诊断，而是编排其他 skill 协同工作，实现性能优化的自动化闭环。

**核心价值**：
- 自动化编译运行，消除人工干预断点
- 迭代优化循环，持续改进系统性能
- 收敛判断，避免无效迭代
- 完整优化日志，可追溯每次改动

## 触发词

- "自动优化"
- "性能优化"
- "迭代优化"
- "optimizer"
- "帮我优化这个系统"
- "自动跑几轮优化"

## 依赖

**必需 skill**：
- `slam-project-profiler`：生成 project-spec.md（包含构建/运行配置）
- `slam-eval-runner`：评估轨迹精度
- `slam-log-analyzer`：分析日志和插桩
- `slam-debug-helper`：诊断根因并给出修复建议

**必需配置**：
- `{project}/.specs/project-spec.md`：包含构建、运行、评估配置

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_path | string | ✅ | 项目根目录绝对路径 |
| max_iterations | int | ⬜ | 最大迭代次数（默认 10） |
| target_metric | string | ⬜ | 目标指标（如 "ate_rmse < 0.1"） |
| auto_apply | bool | ⬜ | 是否自动应用修复（默认 false，需用户确认） |

## 输出产物

```
{project}/.specs/optimization/
└── {timestamp}_{session_id}/
    ├── optimization-config.json       # 优化配置
    ├── iteration-log.json             # 迭代日志（每轮迭代的详细记录）
    ├── iterations/
    │   ├── iter_001/
    │   │   ├── build.log              # 构建日志
    │   │   ├── run.log                # 运行日志
    │   │   ├── eval-report.md         # 评估报告
    │   │   ├── log-analysis.md        # 日志分析报告
    │   │   ├── debug-report.md        # 诊断报告
    │   │   ├── changes.json           # 本轮改动
    │   │   └── trajectory.txt         # 输出轨迹
    │   ├── iter_002/
    │   │   └── ...
    │   └── ...
    └── optimization-report.md         # 最终优化报告
```

## 五步法工作流

```
Phase 0: 初始化        → 读取配置，检查依赖，初始化优化会话
Phase 1: 自动构建      → 编译项目，捕获构建错误
Phase 2: 自动运行      → 运行 SLAM 系统，监控进程状态
Phase 3: 迭代优化      → 评估 → 分析 → 诊断 → 修复 → 回到 Phase 1
Phase 4: 收敛判断      → 检查是否达到目标，生成优化报告
```

### 依赖关系

```
Phase 0 ──────→ Phase 1 ──────→ Phase 2 ──────→ Phase 3
（初始化）       （构建）         （运行）         （迭代优化）
                                                      ↓
                                                  Phase 4
                                                （收敛判断）
```

Phase 3 是循环：
```
Phase 3 内部循环：
  ├─ 3.1: 运行 eval-runner 评估
  ├─ 3.2: 运行 log-analyzer 分析
  ├─ 3.3: 运行 debug-helper 诊断
  ├─ 3.4: 生成修复建议
  ├─ 3.5: 应用修复（可选，需确认）
  └─ 3.6: 回到 Phase 1 重新构建运行
```

## 执行模式

### 模式 A：完整自动优化（默认）

用户说："自动优化" 或 "帮我优化这个系统"

执行流程：
1. Phase 0-2：初始化、构建、首次运行
2. Phase 3：进入迭代优化循环
   - 评估当前性能
   - 分析日志找出问题
   - 诊断根因并给出修复
   - 应用修复（需用户确认）
   - 重新构建运行
   - 重复直到收敛或达到最大迭代次数
3. Phase 4：生成优化报告

### 模式 B：单次迭代

用户说："跑一轮优化" 或 "optimize once"

执行流程：
1. Phase 0-2：初始化、构建、运行
2. Phase 3：执行一次完整的评估-分析-诊断-修复
3. 暂停，等待用户确认是否继续

### 模式 C：从已有运行结果继续

用户说："从上次结果继续优化" 或 "continue optimization"

执行流程：
1. 读取已有的 iteration-log.json
2. 从上次中断的迭代继续
3. Phase 3-4：继续迭代优化

## Phase 编排详情

| Phase | 文件 | 名称 | 可独立执行 |
|-------|------|------|-----------|
| 0 | `phases/phase0-init.md` | 初始化 | ✅ |
| 1 | `phases/phase1-build.md` | 自动构建 | ✅（需 Phase 0） |
| 2 | `phases/phase2-run.md` | 自动运行 | ✅（需 Phase 1） |
| 3 | `phases/phase3-optimize.md` | 迭代优化 | ✅（需 Phase 2） |
| 4 | `phases/phase4-converge.md` | 收敛判断 | ✅（需 Phase 3） |

## 输出模板

| 模板文件 | 用途 |
|---------|------|
| `templates/optimization-report-template.md` | 最终优化报告格式 |

## 全局约定

### project-spec.md 必需配置

为了让 perf-optimizer 能自动工作，project-spec.md 必须包含：

```markdown
## 构建配置
- 构建系统: CMake / Catkin / Colcon
- 构建目录: ./build
- 构建命令: cmake .. && make -j4
- 依赖检查: OpenCV, Eigen, Ceres

## 运行配置
- 可执行文件: ./bin/slam_system
- 数据集路径: /path/to/dataset
- 参数文件: ./config/params.yaml
- 运行命令模板: {executable} --dataset {dataset} --config {config}
- 输出目录: ./output
- 超时时间: 300 秒

## 评估配置
- 真值文件: /path/to/groundtruth.txt
- 评估脚本: ./scripts/evaluate.py
- 评估命令: python {script} --traj {output}/trajectory.txt --gt {gt}
```

### 迭代日志格式

iteration-log.json 记录每轮迭代的详细信息：

```json
{
  "version": "1.0",
  "project": "sf_slam",
  "start_time": "2026-08-20T14:00:00Z",
  "max_iterations": 10,
  "target_metric": "ate_rmse < 0.1",
  "iterations": [
    {
      "id": 1,
      "timestamp": "2026-08-20T14:00:00Z",
      "changes": [],
      "metrics": {
        "ate_rmse": 0.25,
        "ate_max": 0.45,
        "rpe_rmse": 0.05
      },
      "issues": ["轨迹漂移", "特征数不足"],
      "fixes": [],
      "duration_sec": 120,
      "status": "baseline"
    },
    {
      "id": 2,
      "timestamp": "2026-08-20T14:05:00Z",
      "changes": [
        {
          "type": "parameter",
          "file": "config/params.yaml",
          "description": "增加特征点数量阈值",
          "before": "max_features: 150",
          "after": "max_features: 200"
        }
      ],
      "metrics": {
        "ate_rmse": 0.18,
        "ate_max": 0.35,
        "rpe_rmse": 0.04
      },
      "issues": ["特征数仍然不足"],
      "fixes": ["调整特征提取参数"],
      "duration_sec": 115,
      "status": "improved"
    }
  ],
  "final_status": "converged",
  "total_iterations": 5,
  "total_duration_sec": 600
}
```

### 收敛判断标准

优化循环在以下情况下停止：

1. **达到目标**：指标满足用户设定的目标
   ```
   ✅ 收敛: ate_rmse = 0.08 < 0.1 (目标)
   ```

2. **性能不再提升**：连续 3 轮迭代改进 < 1%
   ```
   ⚠️ 收敛: 连续 3 轮改进 < 1%，可能陷入局部最优
   ```

3. **达到最大迭代次数**：防止无限循环
   ```
   ⚠️ 停止: 达到最大迭代次数 (10)
   ```

4. **性能恶化**：指标比基线差 > 10%
   ```
   ❌ 回退: 性能恶化，回退到上一轮
   ```

5. **构建/运行失败**：无法继续
   ```
   ❌ 失败: 构建失败或运行崩溃
   ```

### 修复应用策略

**默认策略**：每轮修复前暂停，等待用户确认

```
🔧 第 2 轮优化建议

检测到问题: 特征数不足 (平均 120 < 目标 150)

建议修复:
1. 修改 config/params.yaml
   - max_features: 150 → 200
   - 原因: 增加特征点数量，提高跟踪稳定性

是否应用此修复？(Y/n)
```

**自动模式**：用户设置 `auto_apply=true`，自动应用修复

```
⚠️ 自动模式已启用

将自动应用所有修复建议。如需人工确认，请设置 auto_apply=false。
```

### 错误处理

**构建失败**：
```
❌ 第 3 轮构建失败

错误信息:
```
error: 'undeclared identifier' in tracker.cpp:123
```

诊断: 代码修改引入语法错误

建议:
1. 检查 tracker.cpp:123 的修改
2. 手动修复或回退到上一轮

是否回退到第 2 轮？(Y/n)
```

**运行崩溃**：
```
❌ 第 3 轮运行崩溃

崩溃信息: Segmentation fault at 0x7f8a1234

诊断: 调用 debug-helper 分析 core dump

建议:
1. 运行 debug-helper 分析崩溃原因
2. 修复后重新构建运行

是否继续？(Y/n)
```

**性能恶化**：
```
⚠️ 第 4 轮性能恶化

指标对比:
- 第 3 轮: ate_rmse = 0.12
- 第 4 轮: ate_rmse = 0.18 (+50%)

原因: 修复引入新问题

建议: 回退到第 3 轮

是否回退？(Y/n)
```

## 与其他 skill 的协作

```
slam-perf-optimizer (编排器)
    ├─ 调用 slam-eval-runner      → 评估轨迹精度
    ├─ 调用 slam-log-analyzer     → 分析日志和插桩
    ├─ 调用 slam-debug-helper     → 诊断根因并修复
    └─ 读取 project-spec.md       → 获取构建/运行配置
```

## 使用示例

### 示例 1：完整自动优化

```
用户: 帮我优化这个系统，目标 ate_rmse < 0.1

AI: 🚀 启动性能优化

📋 优化配置:
- 项目: sf_slam
- 目标: ate_rmse < 0.1
- 最大迭代: 10 轮

Phase 0: 初始化 ✅
Phase 1: 构建 ✅ (耗时 45s)
Phase 2: 运行 ✅ (耗时 120s)

Phase 3: 迭代优化

--- 第 1 轮 ---
评估: ate_rmse = 0.25 ❌
分析: 特征数不足 (120)，优化不稳定
诊断: 特征提取参数过保守
修复: 增加 max_features (150 → 200)
应用修复? (Y/n) y
重新构建... ✅
重新运行... ✅

--- 第 2 轮 ---
评估: ate_rmse = 0.18 ❌ (改进 28%)
分析: 特征数改善 (180)，但仍有漂移
诊断: IMU 噪声参数偏大
修复: 调整 gyro_noise (0.01 → 0.005)
应用修复? (Y/n) y
重新构建... ✅
重新运行... ✅

--- 第 3 轮 ---
评估: ate_rmse = 0.12 ❌ (改进 33%)
分析: 性能接近目标
诊断: 外参平移有微小偏差
修复: 调整 T_cam_imu 平移 (x: +0.002m)
应用修复? (Y/n) y
重新构建... ✅
重新运行... ✅

--- 第 4 轮 ---
评估: ate_rmse = 0.08 ✅ (改进 33%)

Phase 4: 收敛判断 ✅

📊 优化报告:
- 总迭代: 4 轮
- 总耗时: 8 分钟
- 初始: ate_rmse = 0.25
- 最终: ate_rmse = 0.08 (改进 68%)
- 目标: ✅ 达到 (0.08 < 0.1)

详细报告: {project}/.specs/optimization/{timestamp}/optimization-report.md
```

### 示例 2：单次迭代

```
用户: 跑一轮优化

AI: 🔄 执行单轮优化

Phase 0-2: 初始化、构建、运行 ✅

Phase 3: 单轮优化
评估: ate_rmse = 0.25
分析: 特征数不足
诊断: 调整 max_features
修复: max_features 150 → 200
应用修复? (Y/n) y
重新构建... ✅
重新运行... ✅
新评估: ate_rmse = 0.18 (改进 28%)

⏸️ 单轮优化完成

性能: 0.25 → 0.18 (改进 28%)
是否继续下一轮？(Y/n)
```

## 注意事项

1. **构建时间**：首次构建可能较慢，后续增量构建较快
2. **运行时间**：根据数据集大小，运行可能需要几分钟到几十分钟
3. **磁盘空间**：每轮迭代需要保存日志和轨迹，注意磁盘空间
4. **参数回退**：如果性能恶化，支持回退到上一轮
5. **用户确认**：默认每轮修复前需要用户确认，避免自动引入问题
6. **最大迭代**：设置合理的最大迭代次数，防止无限循环
7. **并发安全**：同一时间只能运行一个优化会话
