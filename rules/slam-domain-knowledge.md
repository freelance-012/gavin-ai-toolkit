# SLAM 领域知识库

> 本文件存储 SLAM/VIO 领域的通用知识，供 Skill 和 Agent 引用。
> 内容持续积累和更新。

---

## 主流框架特征对照表

| 框架 | 类型 | 传感器 | 状态管理 | 优化方法 | 初始化 | 回环检测 |
|------|------|--------|---------|---------|--------|---------|
| **VINS-Mono** | 单目 VIO | Mono + IMU | 滑动窗口 | 紧耦合 BA (Ceres) | SfM + IMU 对齐 | 无 (原版) |
| **VINS-Fusion** | 多传感器 VIO | Mono/Stereo + IMU + GPS | 滑动窗口 | 紧耦合 BA (Ceres) | SfM + IMU 对齐 | 位姿图 (DBoW2) |
| **ORB-SLAM3** | 多模式 | Mono/Stereo/RGB-D + IMU | 关键帧地图 + 多地图 | 紧耦合 BA (g2o) | 分阶段 IMU 初始化 | DBoW2 词袋 |
| **OpenVINS** | 多传感器 VIO | Mono/Stereo + IMU (+baro) | MSCKF 滤波器 | EKF 更新 | 离线初始化 | 无 / 可选 |
| **Kimera** | 多传感器 | Stereo + IMU + Lidar | 因子图 | iSAM2 (GTSAM) | IMU 预积分 | 回环检测 |
| **BASALT** | 视觉惯性 | Mono/Stereo + IMU | 滑动窗口 | 紧耦合 BA (Ceres) | SfM + 重力对齐 | 无 |
| **FAST-LIO** | 激光惯性 | LiDAR + IMU | 迭代 EKF | 紧耦合 (直接配准) | 粗到精对齐 | 可选 (GPS) |

---

## 核心算法概念速查

### 预积分 (Preintegration)

**核心思想**: 将两帧之间的 IMU 测量预积分，使得在优化时调整 bias 不需要重新积分所有 IMU 数据。

**关键公式**:
- 位置增量: αᵢⱼ (delta_p_)
- 速度增量: βᵢⱼ (delta_v_)
- 旋转增量: γᵢⱼ (delta_q_)

**论文**: Forster et al., "On-Manifold Preintegration for Real-Time Visual-Inertial Odometry", IEEE TRO 2017

### 边缘化 (Marginalization)

**核心思想**: 当滑动窗口满时，将最旧帧（或次新帧）的约束通过 Schur 补转化为先验信息，保持计算量恒定。

**关键概念**:
- Schur 补: 将线性系统分块后消去部分变量
- FEJ (First Estimate Jacobian): 使用首次估计的雅可比避免一致性过约
- 先验残差: 边缘化后的信息保留为 residual factor

### 初始化策略对比

| 方法 | 流程 | 优点 | 缺点 |
|------|------|------|------|
| SfM + IMU 对合 | 纯视觉 SfM → 尺度/重力/速度/bias 联合估计 | 理论清晰 | SfM 可能失败 |
| 分阶段初始化 | 纯视觉 → 视觉惯性 → 完整 VI | 逐步稳定 | 步骤多、耗时 |
| 离线初始化 | 提供初始轨迹 → 在线精化 | 简单可靠 | 需要离线数据 |

---

## 常见代码模式识别

### 特征提取相关关键词

```
detect, extract, feature, corner, keypoint
ORB, FAST, Harris, Shi-Tomasi, SuperPoint, Grid
goodFeaturesToTrack, detectAndCompute
```

### 特征跟踪相关关键词

```
track, match, optical_flow, KLT, Lucas-Kanade
calcOpticalFlowPyrLK, descriptorMatcher
grid, uniform distribution
```

### 优化相关关键词

```
optimize, solve, minimize, cost, residual, factor
ceres::Problem, ceres::Solver, ceres::CostFunction
g2o::BaseVertex, g2o::BaseEdge, g2o::OptimizationAlgorithm
AddResidualBlock, SetParameterization, LocalParameterization
LossFunction, HuberLoss, CauchyLoss
```

### 四元数操作相关关键词

```
quaternion, Quaterniond, quat, rotmat
R2q, q2R, ypr2R, R2ypr, eulerAngle
Log, Exp, normalize, conjugate, inverse
slerp, boxplus, boxminus
```
