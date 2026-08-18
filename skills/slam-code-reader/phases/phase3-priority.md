# Phase 3: 模块优先级标注

## 目标

根据模块在数据流中的位置和功能关键词，自动分类 P0/P1/P2/P3。生成阅读优先级清单，帮助用户合理分配精力。

## 触发词

- "标注优先级"
- "哪些模块重要"
- "模块分类"

## 依赖

**必需**: `01_拓扑结构分析.md`（需要目录结构和模块列表）

**可选**: `02_数据流追踪.md`（有则更准确，可结合数据流位置判断优先级）

**检查逻辑**：
```
如果 01_拓扑结构分析.md 不存在:
    → 停止，提示先执行 Phase 1
```

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| repo_path | string | ✅ | 仓库根目录绝对路径 |

## 输出产物

```
{仓库名}-code-analysis/
└── 03_模块优先级清单.md
```

## 优先级分类标准

### P0 — 核心数学（必须逐行精读）

**识别关键词**：

| 类别 | 关键词 |
|------|--------|
| 预积分 | `preintegration`, `preintegrated`, `IntegrationBase`, `push_back`, `evaluate`, `propagate`, `midPointIntegration`, `alpha`, `beta`, `gamma`, `delta_p`, `delta_v`, `delta_q` |
| 优化/BA | `optimize`, `solveBA`, `bundle_adjustment`, `ceres::`, `g2o::`, `Solve`, `CostFunction`, `AutoDiffCostFunction`, `AddResidualBlock`, `LinearSolver`, `Schur` |
| 初始化 | `initial`, `initialize`, `bootstrap`, `SfM`, `triangulate`, `align`, `gravity`, `refineGravity`, `linearAlignment`, `visualInitial` |
| 边缘化 | `marginalize`, `marginalization`, `MarginalizationFactor`, `PriorFactor`, `Schur`, `FEJ`, `FirstEstimate` |
| 残差/因子 | `residual`, `factor`, `reprojection_error`, `project`, `computeError` |

**阅读深度**：逐行精读 + 公式对照
**预估时间**：每个 P0 模块 2-4 小时

### P1 — 系统管理（理解策略即可）

**识别关键词**：

| 类别 | 关键词 |
|------|--------|
| 滑动窗口 | `window`, `slide`, `SlideWindow`, `slideWindow`, `slideWindowOld` |
| 关键帧 | `keyframe`, `KeyFrame`, `selectKeyframe`, `isKeyframe` |
| 跟踪状态 | `tracking`, `track_lost`, `lost`, `reset`, `failure`, `restart`, `determineStatus` |
| 特征管理 | `feature`, `FeatureManager`, `addFeature`, `removeFailures` |

**阅读深度**：理解策略逻辑，不需要逐行推导公式
**预估时间**：每个 P1 模块 30-60 分钟

### P2 — 工程辅助（扫一眼）

**识别关键词**：

| 类别 | 关键词 |
|------|--------|
| 可视化 | `viewer`, `visualize`, `publishOdometry`, `draw`, `rviz`, `vtk` |
| 日志/调试 | `log`, `debug`, `print`, `printf`, `ROS_INFO`, `spdlog` |
| 配置/参数 | `param`, `config`, `readParam`, `node_handle.param`, `YAML::LoadFile`, `cv::FileStorage` |
| ROS通信 | `publisher`, `subscriber`, `advertise`, `service`, `action` |

**阅读深度**：了解接口即可
**预估时间**：每个 P2 模块 10-15 分钟

### P3 — 工具类（按需查）

**识别关键词**：

| 类别 | 关键词 |
|------|--------|
| 数学工具 | `quaternion`, `Quaterniond`, `rotation`, `transform`, `Utility`, `eulerAngle`, `R2ypr`, `ypr2R` |
| 几何运算 | `triangulate`, `Parallax2D`, `coordinateTransform` |
| 通用工具 | `Logger`, `Timer`, `Filename`, `ConfigReader`, `macro`, `typedef` |

**阅读深度**：用到时查函数签名
**预估时间**：按需，通常不主动读

## 执行步骤

### Step 1: 列出所有模块

从 Phase 1 的结果中提取完整模块列表（目录或文件组）。

### Step 2: Grep 关键词搜索

对每个模块的源文件，搜索上述 P0-P3 的关键词。

统计：
- 匹配到的关键词数量
- 匹配到的类别分布（如同时匹配到 P0 和 P1 的关键词）

### Step 3: 综合评定优先级

**评定规则**：
1. 如果匹配到 **任意一个 P0 关键词** → 至少为 P0
2. 如果只匹配到 P1 关键词且无 P0 → P1
3. 如果只匹配到 P2 关键词 → P2
4. 如果只匹配到 P3 或无匹配 → P3
5. **人工修正因素**：
   - 该模块在数据流中的位置越靠后端（接近优化输出）→ 可能提升优先级
   - 代码量特别大但全是 P2 关键词 → 保持 P2（大不代表重要）
   - 目录名明确是 `third_party/`, `vendor/` → 直接跳过不标注

### Step 4: 统计代码量

对每个模块估算代码行数：
```bash
# 对每个模块目录
find {module_path} -name "*.cpp" -o -name "*.h" -o -name "*.hpp" | xargs wc -l
```

### Step 5: 生成报告

套用 `templates/priority-list-template.md` 格式：

```markdown
# 03_模块优先级清单

> 仓库: {仓库名} | 生成日期: {日期}

## 1. 优先级总览图
   (可视化: P0 ████ 核心  | P1 ███ 重要  | P2 ██ 辅助  | P3 █ 工具)

## 2. P0 核心模块 (必须精读)
   | # | 模块名 | 路径 | 关键词匹配 | 代码行数 | 预估时间 | 建议阅读顺序 |

## 3. P1 系统管理模块 (理解策略)
   (同上格式)

## 4. P2 工程辅助模块 (扫一眼)
   (同上格式)

## 5. P3 工具类 (按需查)
   (同上格式)

## 6. 阅读时间估算汇总
   | 优先级 | 模块数 | 总代码行数 | 总预估时间 |

## 7. 推荐阅读路线 (初步)
   基于 P0→P1→P2→P3 + 数据流依赖关系给出建议顺序
   (详细路线图在 Phase 6 中完善)
```

## 注意事项

1. **关键词表是经验总结**：不同项目可能用不同的命名习惯，如果某个明显重要的模块没有匹配到任何关键词，手动提升其优先级
2. **P0 不一定多**：一个小型 SLAM 项目可能只有 2-3 个 P0 模块，这是正常的
3. **本 Phase 的产出是 Phase 4 的输入**：Phase 4 将根据此清单决定精读哪些模块
