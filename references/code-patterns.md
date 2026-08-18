# SLAM 代码常见模式识别指南

> 阅读新代码库时，通过这些模式快速定位关键逻辑。
> 按"看到什么 → 意味着什么"组织。

---

## 模式 1: 特征提取

### 看到这些 → 在做特征提取

```cpp
// OpenCV 特征点检测
cv::goodFeaturesToTrack()      // Shi-Tomasi / Harris
detector->detectAndCompute()    // ORB, SIFT, SURF, AKAZE
FastFeatureDetector             // FAST 角点
```

**常见变体**:
- Grid feature: 将图像分格，每格提取固定数量特征（均匀分布）
- SuperPoint: 神经网络特征（需要模型文件）
- GFTT + 光流: 传统 VIO 常用组合

**关注点**:
- 最大特征数 (`max_features`, `max_corners`)
- 图像金字塔层数 (影响尺度不变性)
- FAST 阈值或 ORB nfeatures

---

## 模式 2: 特征跟踪

### 看到这些 → 在做特征跟踪

```cpp
// KLT 光流跟踪
cv::calcOpticalFlowPyrLK()     // Lucas-Kanade 金字塔光流

// 描述子匹配
matcher->knnMatch()             // 最近邻匹配
bfMatcher.match()               // 暴力匹配
```

**常见流程**:
1. 对上一帧的每个特征，在当前帧搜索匹配
2. 用 RANSAC/Homography/F-matrix 剔除外点
3. 统计跟踪率，低于阈值则触发特殊处理

**关注点**:
- 金字塔层数 (`pyr_levels`)
- 搜索窗口大小 (`win_size`)
- RANSAC 阈值 (`ransac_threshold`)

---

## 模式 3: IMU 数据处理

### 看到这些 → 在处理 IMU

```cpp
// 回调函数签名
void imuCallback(const sensor_msgs::ImuConstPtr &msg);

// 积分相关
push_back(dt, acc, gyro)        // 新增测量
midPointIntegration()           // 中点积分
propagate()                     // 状态传播

// 成员变量命名规律
delta_p_, delta_v_, delta_q_    // 预积分三件套
jac_a_, jac_g_                  // bias 雅可比
covariance_                     // 协方差矩阵
linearized_ba_, linearized_bg_  // 线性化点的 bias
```

**IMU 处理的标准流程**:
1. 接收回调 → 存入 buffer 或队列
2. 当有图像帧到来时，取出两帧之间的所有 IMU 数据
3. 调用 `push_back()` 逐个积分
4. 得到预积分结果 + 雅可比 + 协方差

---

## 模式 4: 优化问题构建

### 看到这些 → 在构建非线性优化问题

```cpp
// Ceres Solver
ceres::Problem problem;
problem.AddResidualBlock(
    new ceres::AutoDiffCostFunction<CostFunctor, RESIDUAL_DIM, ...>(new CostFunctor(args...)),
    loss_function,              // 可选: HuberLoss, CauchyLoss
    para_pose, para_speed_bias   // 参数块指针
);
problem.SetParameterization(para_pose, new QuaternionParameterization());

// g2o
g2o::SparseOptimizer optimizer;
optimizer.addVertex(vertex);
optimizer.addEdge(edge);
optimizer.optimize(iterations);
```

**参数化方式速查**:
| 参数 | 参数化维度 | LocalParameterization |
|------|-----------|----------------------|
| 位姿 SE(3) | 7 (q + t) | `QuaternionParameterization` (四元数 4→3) |
| 速度+bias | 9 | 无 (直接优化) |
| 地图点 | 3 | 无 |

---

## 模式 5: 边缘化操作

### 看到这些 → 在做边缘化

```cpp
marginalization->marginalizeOldFrame();     // 边缘化最旧帧
marginalization->marginalizeNewFrame();     // 边缘化次新帧 (关键帧策略)
prior_factor = marginalization->getLastMarginalizationInfo();
```

**边缘化的标准流程**:
1. 构建线性系统 Hx = b（包含所有待边缘化和保留的状态）
2. 对要消去的变量做 Schur 补
3. 将 Schur 补结果作为先验 residual factor
4. 下次优化时加入这个先验因子

**判断边缘化对象**:
- 最旧帧边缘化: 窗口满时触发
- 次新帧边缘化: 当前帧被选为关键帧时触发

---

## 模式 6: 初始化流程

### 看到这些 → 在做初始化

```cpp
initialStructure();          // 纯视觉 SfM
visualInitialSFM();          // 同上（不同命名）
imuInitialAlign();           // IMU 与 SfM 结果对合
refineGravity();             // 重力矢量精修
linearAlignment();           // 尺度/速度/bias 联合求解
```

**VINS 类初始化标准流程**:
1. 纯视觉 SfM（需要一定视差/平移）
2. SfM 结果与 IMU 预积分对齐
3. 联合估计: 尺度 s、重力 g、速度 v、bias b
4. 三角化地图点（如果还没做）

**ORB-SLAM3 初始化流程**:
1. 单目: 至少两帧，三角化初始地图
2. 双目: 第一帧即可初始化
3. 有 IMU: 分阶段（纯视觉 → 视觉惯性 → 完整 VI）

---

## 模式 7: 关键帧选择

### 看到这些 → 在做关键帧判定

```cpp
if (isKeyframe(current_frame)) { ... }

// 常用判定条件
parallax_sum > min_parallax    // 视差足够大
tracked_points > min_features // 跟踪点足够多
```

**常见判定条件组合**:
1. **视差条件**: 与最近关键帧的平均视差 > 阈值
2. **跟踪率**: 跟踪成功的特征比例 > 阈值
3. **时间间隔**: 距上一关键帧超过 N 帧
4. **内点比例**: RANSAC 后内点足够多

---

## 模式 8: 可视化发布

### 看到这些 → 在发布可视化数据

```cpp
pubOdometry(msg);            // 发布里程计话题
pubPointCloud(msg);          // 发布点云
pubKeyPoses(msg);            // 发布关键帧位姿
pubCameraPose(msg);          // 发布相机位姿
pubTF(msg);                  // 发布 TF 变换
```

**ROS 话题命名惯例**:
| 话题名 | 内容 | 类型 |
|--------|------|------|
| `/odometry` | 最新位姿 | nav_msgs/Odometry |
| `/pose_graph` | 位姿图节点 | nav_msgs/Odometry[] |
| `/key_poses` | 所有关键帧 | geometry_msgs/PoseArray |
| `/point_cloud` | 地图点/特征点 | sensor_msgs/PointCloud2 |
| `/camera_pose_visual` | 相机轨迹可视化 | visualization_msgs/Marker |

---

*持续更新中。遇到新模式时随时补充。*
