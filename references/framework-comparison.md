# 主流 SLAM/VIO 框架特征对照表

> 用于快速了解不同框架的定位和特点，帮助选择合适的技术路线。

---

## 按类型分类

### 视觉惯性里程计 (VIO)

| 框架 | 传感器 | 状态表示 | 优化方法 | 初始化 | 回环 | 开源 | 维护状态 |
|------|--------|---------|---------|--------|------|------|---------|
| **VINS-Mono** | Mono + IMU | 滑动窗口 (10帧) | 紧耦合 BA (Ceres) | SfM + IMU 对合 | 无 | ✅ GitHub | 基本停止 |
| **VINS-Fusion** | M/S/G + IMU + GPS | 滑动窗口 | BA (Ceres) | SfM + IMU 对合 | DBoW2 位姿图 | ✅ GitHub | 活跃 |
| **OpenVINS** | M/S + IMU (+baro) | MSCKF 滤波器 | EKF 更新 | 离线初始化 | 无/可选 | ✅ GitHub | 活跃 |
| **BASALT** | Mono/Stereo + IMU | 滑动窗口 | BA (Ceres) | SfM + 重力对齐 | 无 | ✅ GitHub | 活跃 |
| **OpenVINS-FI** | Stereo + IMU | MSCKF + 滤波 | EKF | 离线 | 可选 | ✅ GitHub | - |
| **ROVIO** | Mono + IMU | 滤波器 | EKF | 手动给定 | 无 | ✅ GitHub | 停止 |

### 视觉 SLAM

| 框架 | 传感器 | 地图形式 | 优化方法 | 回环 | 实时性 | 特点 |
|------|--------|---------|---------|------|--------|------|
| **ORB-SLAM3** | M/S/RGBD + IMU | 关键帧地图 + 多地图 | BA (g2o) | DBoW2 词袋 | 实时 | 多模式、最完整 |
| **ORB-SLAM2** | M/S/RGBD | 关键帧地图 | BA (g2o) | DBoW2 词袋 | 实时 | 经典，无 IMU |
| **PTAM** | Mono | 关键帧地图 | BA | 无 | 实时 | 开山之作，已过时 |

### 激光 / 激光-视觉融合

| 框架 | 传感器 | 方法 | 回环 | 实时性 | 特点 |
|------|--------|------|------|--------|------|
| **LOAM** | 3D LiDAR | 点面特征 + ICP | 无 | 实时 | 经典激光 odometry |
| **LeGO-LOAM** | 3D LiDAR | 地面+边缘分割 + LOAM | 无 | 实时 | 适合地面车辆 |
| **FAST-LIO2** | LiDAR + IMU | 紧耦合迭代 EKF | 可选 | 高效 | 当前 SOTA 级别 |
| **LVI-SAM** | Stereo + LiDAR + IMU | 紧耦合因子图 | 有 | 实时 | 激光-视觉-惯性紧耦合 |

## 按优化方法分类

### 基于优化的 (Bundle Adjustment)

| 框架 | 优化器 | 边缘化 | 特点 |
|------|--------|--------|------|
| VINS 系列 | Ceres | Schur 补 | 滑动窗口 + 先验 |
| ORB-SLAM3 | g2o | 本质图 | 关键帧剔除策略 |
| BASALT | Ceres | Schur 补 | 与 VINS 类似但更简洁 |
| Kimera | GTSAM (iSAM2) | 增量平滑 | 因子图框架 |

### 基于滤波的 (EKF / MSCKF)

| 框架 | 滤波器类型 | 状态维度 | 特点 |
|------|-----------|---------|------|
| OpenVINS | Extended KF | ~25 (MSCKF loss) | 计算高效 |
| ROVIO | Extended KF | ~20+ | 直接法，轻量 |
| MSCKF (原始) | EKF | 变长 | 只保留滑动窗口状态 |

## 选择指南

### 按应用场景选

| 场景 | 推荐框架 | 原因 |
|------|---------|------|
| 无人机 (计算受限) | OpenVINS / BASALT | 轻量、实时性好 |
| AR/VR (需要高精度) | ORB-SLAM3 / BASALT | 精度高、重定位好 |
| 地面机器人 (多传感器) | VINS-Fusion / LVI-SAM | 支持多传感器融合 |
| 学术研究 / 入门学习 | ORB-SLAM3 / VINS-Mono | 文档齐全、社区大 |
| 激光为主 | FAST-LIO2 | SOTA 性能、效率高 |

### 按传感器配置选

| 传感器组合 | 推荐选项 |
|-----------|---------|
| 单目 + IMU | VINS-Mono, BASALT, OpenVINS |
| 双目 + IMU | VINS-Fusion, OpenVINS, ORB-SLAM3 |
| 双目 (无 IMU) | ORB-SLAM3, ZED SDK |
| 单目 (无 IMU) | ORB-SLAM2/3 (纯视觉模式) |
| 激光 + IMU | FAST-LIO2, LIO-SAM |
| 全套 (激光+视觉+IMU) | LVI-SAM, R³LIVE |
