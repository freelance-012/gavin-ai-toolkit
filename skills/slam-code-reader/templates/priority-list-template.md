# 模块优先级清单模板

> 此模板供 Phase 3 生成 `03_模块优先级清单.md` 时套用

---

# 03_模块优先级清单

> **仓库**: {仓库名}
> **生成日期**: {YYYY-MM-DD HH:MM}
> **分析者**: Gavin + AI

---

## 1. 优先级总览

```
P0 ████ 核心数学 (必须逐行精读，含公式推导)
P1 ████ 系统管理 (理解策略逻辑)
P2 ██   工程辅助 (了解接口即可)
P3 █    工具类 (按需查阅)
```

| 优先级 | 定义 | 阅读深度 | 模块数 | 总代码行数 |
|--------|------|---------|--------|-----------|
| **P0** | 核心数学：预积分、BA、初始化、边缘化、残差因子 | 逐行精读 + 公式对照 | {N} | ~{N}k |
| **P1** | 系统管理：滑动窗口、关键帧选择、跟踪状态、特征管理 | 理解策略即可 | {N} | ~{N}k |
| **P2** | 工程辅助：可视化、日志、配置、ROS通信 | 扫一眼接口 | {N} | ~{N}k |
| **P3** | 工具类：四元数运算、坐标变换、通用工具 | 用到时查 | {N} | ~{N}k |

---

## 2. P0 核心模块（必须精读）

| # | 模块名 | 路径 | 匹配到的关键词 | 代码行数 | 预估时间 | 建议阅读顺序 |
|---|--------|------|---------------|---------|---------|-------------|
| 1 | `{ModuleA}` | `{path}` | `optimize, ceres, CostFunction, AddResidualBlock` | ~{N} 行 | 3-4 h | 第 {N} 个读 |
| 2 | `{ModuleB}` | `{path}` | `preintegration, push_back, midPointIntegration, delta_p` | ~{N} 行 | 2-3 h | 第 {N} 个读 |
| 3 | ... | ... | ... | ... | ... | ... |

### P0 模块关键词匹配详情

| 模块 | P0 关键词命中 | 具体匹配项 |
|------|--------------|-----------|
| `{ModuleA}` | {N} 次 | `ceres::Problem`(x), `AddResidualBlock`(x), `AutoDiffCostFunction`(x) |
| `{ModuleB}` | {N} 次 | `IntegrationBase`(x), `push_back`(x), `midPointIntegration`(x) |

---

## 3. P1 系统管理模块（理解策略）

| # | 模块名 | 路径 | 匹配到的关键词 | 代码行数 | 预估时间 | 建议阅读顺序 |
|---|--------|------|---------------|---------|---------|-------------|
| 1 | `{ModuleC}` | `{path}` | `window, slideWindow, keyframe` | ~{N} 行 | 30-60 min | ... |
| 2 | ... | ... | ... | ... | ... | ... |

---

## 4. P2 工程辅助模块（扫一眼）

| # | 模块名 | 路径 | 匹配到的关键词 | 代码行数 | 预估时间 |
|---|--------|------|---------------|---------|---------|
| 1 | `{ModuleD}` | `{path}` | `viewer, publish, visualize` | ~{N} 行 | 10-15 min |
| 2 | ... | ... | ... | ... | ... |

---

## 5. P3 工具类（按需查）

| # | 模块名/文件 | 路径 | 功能说明 | 何时需要查 |
|---|------------|------|---------|-----------|
| 1 | `{Utility}` | `{path}` | 四元数/旋转矩阵工具函数 | 读到坐标变换时 |
| 2 | ... | ... | ... | ... |

---

## 6. 阅读时间估算汇总

| 优先级 | 模块数 | 总代码行数 | 总预估时间 | 占比 |
|--------|--------|-----------|-----------|------|
| P0 | {N} | ~{N}k | {N} h | XX% |
| P1 | {N} | ~{N}k | {N} h | XX% |
| P2 | {N} | ~{N}k | {N} h | XX% |
| P3 | {N} | ~{N}k | 按需 | - |
| **总计** | **{N}** | **~{N}k** | **~{N} h** | **100%** |

---

## 7. 推荐阅读路线（初步版）

> 完整路线图将在 Phase 6 中生成。此处给出基于优先级的初步建议。

```
第一轮: 建立全局认知 (~2h)
  ├── 01_拓扑结构分析.md (本报告)
  ├── 02_数据流追踪.md
  └── 本文件 (03_模块优先级清单)

第二轮: 攻克核心算法 (~8-15h, 按 P0 推荐顺序)
  ├── [ ] Step 1: {第一个P0模块} ({预估时间})
  ├── [ ] Step 2: {第二个P0模块} ({预估时间})
  ├── [ ] Step 3: ...
  └── [ ] Step N: {最后一个P0模块}

第三轮: 理解系统设计 (~2-4h, P1 模块)
  ├── ...

第四轮: 了解工程细节 (~30min-1h, P2 + 按需查 P3)
  ├── ...
```

---

## 附录：完整关键词表

### P0 关键词（核心数学）

| 类别 | 关键词列表 |
|------|-----------|
| 预积分 | `preintegration`, `preintegrated`, `IntegrationBase`, `push_back`, `evaluate`, `propagate`, `midPointIntegration`, `alpha`, `beta`, `gamma`, `delta_p`, `delta_v`, `delta_q` |
| 优化/BA | `optimize`, `solveBA`, `bundle_adjustment`, `ceres::`, `g2o::`, `Solve`, `CostFunction`, `AutoDiffCostFunction`, `AddResidualBlock`, `LinearSolver`, `Schur` |
| 初始化 | `initial`, `initialize`, `bootstrap`, `SfM`, `triangulate`, `align`, `gravity`, `refineGravity`, `linearAlignment`, `visualInitial` |
| 边缘化 | `marginalize`, `marginalization`, `MarginalizationFactor`, `PriorFactor`, `Schur`, `FEJ`, `FirstEstimate` |
| 残差/因子 | `residual`, `factor`, `reprojection_error`, `project`, `computeError` |

### P1 关键词（系统管理）

| 类别 | 关键词列表 |
|------|-----------|
| 滑动窗口 | `window`, `slide`, `SlideWindow`, `slideWindowOld` |
| 关键帧 | `keyframe`, `KeyFrame`, `selectKeyframe`, `isKeyframe` |
| 跟踪状态 | `tracking`, `track_lost`, `lost`, `reset`, `failure`, `restart` |
| 特征管理 | `feature`, `FeatureManager`, `addFeature`, `removeFailures` |

### P2 关键词（工程辅助）

| 类别 | 关键词列表 |
|------|-----------|
| 可视化 | `viewer`, `visualize`, `publishOdometry`, `draw`, `rviz` |
| 日志/调试 | `log`, `debug`, `print`, `ROS_INFO`, `spdlog` |
| 配置 | `param`, `config`, `readParam`, `YAML::LoadFile` |
| ROS通信 | `publisher`, `subscriber`, `advertise` |

### P3 关键词（工具类）

| 类别 | 关键词列表 |
|------|-----------|
| 数学工具 | `quaternion`, `Quaterniond`, `rotation`, `transform`, `Utility`, `eulerAngle` |
| 几何运算 | `triangulate`, `Parallax2D`, `coordinateTransform` |
| 通用工具 | `Logger`, `Timer`, `Filename`, `ConfigReader` |
