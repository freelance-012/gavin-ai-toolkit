# 数据流追踪报告模板

> 此模板供 Phase 2 生成 `02_数据流追踪.md` 时套用

---

# 02_数据流追踪

> **仓库**: {仓库名}
> **生成日期**: {YYYY-MM-DD HH:MM}
> **分析者**: Gavin + AI

---

## 1. 传感器输入总览

| 传感器 | 数据类型 | 接口方式 | 话题名 / 文件格式 | 回调函数 | 文件:行号 |
|--------|---------|---------|-------------------|---------|-----------|
| Camera (左/右/RGB) | 图像 | ROS Topic / 直接读取 | `{topic}` / `{format}` | `{callback}` | `{file}:{line}` |
| IMU | 惯性测量 | ROS Topic / 文件读取 | `{topic}` / `.dat` | `{callback}` | `{file}:{line}` |
| ... | ... | ... | ... | ... | ... |

---

## 2. Image 数据流

### 2.1 处理链路图

```
图像原始数据
  │
  ▼
[Step 1: 预处理] ──── {类名}::{方法}() @ {file}:{line}
  │  输入: 原始图像 (cv::Mat)
  │  输出: {处理后数据}
  │  操作: {去畸变? 尺寸调整? 色彩转换?}
  │
  ▼
[Step 2: 特征提取] ─ {类名}::{方法}() @ {file}:{line}
  │  输入: 预处理后的图像
  │  输出: 特征点集合 ({Feature} 类型)
  │  算法: {FAST / ORB / SIFT / Grid / SuperPoint / ...}
  │
  ▼
[Step 3: 特征跟踪] ── {类名}::{方法}() @ {file}:{line}
  │  输入: 当前帧特征 + 上一帧特征
  │  输出: 跟踪成功/失败的特征集合
  │  算法: {KLT / Lucas-Kanada / 光流 / 描述子匹配}
  │
  ▼
[Step 4: 外点剔除] ─ {类名}::{方法}() @ {file}:{line}
  │  输入: 跟踪后的特征
  │  输出: 内点集合
  │  方法: {RANSAC / Fundamental / Homography}
  │
  ▼
[Step 5: 送入后端] ── {类名}::{方法}() @ {file}:{line}
     输入: 内点特征 + IMU 预积分量
     输出: 位姿估计结果
```

### 2.2 各节点详情表

| Step | 操作 | 函数 | 文件:行号 | 输入类型 | 输出类型 | 关键参数 |
|------|------|------|-----------|---------|---------|---------|
| 1 | 预处理 | `fn()` | `{f}:{l}` | `cv::Mat` | `cv::Mat` | - |
| 2 | 特征提取 | `fn()` | `{f}:{l}` | `cv::Mat` | `vector<Feature>` | max_features, threshold |
| ... | ... | ... | ... | ... | ... | ... |

---

## 3. IMU 数据流

### 3.1 处理链路图

```
IMU 原始数据 (acc, gyro, timestamp)
  │
  ▼
[Step 1: 预处理] ──── {类名}::{方法}() @ {file}:{line}
  │  操作: {去偏置? 坐标系变换? 单位转换?}
  │
  ▼
[Step 2: 预积分累积] ─ {IntegrationBase}::push_back() @ {file}:{line}
  │  调用: midPointIntegration() @ {file}:{line}
  │  更新: delta_p_, delta_v_, delta_q_
  │  更新: jac_a_, jac_g_ (雅可比)
  │  更新: covariance_ (协方差)
  │
  ▼
[Step 3: 送入后端优化] ─ 构建IMUFactor @ {file}:{line}
     作为残差约束加入优化问题
```

### 3.2 各节点详情表

（同 2.2 格式）

---

## 4. 其他传感器数据流（如有）

（按需添加：深度、点云、GPS、轮速计等，格式同上）

---

## 5. 核心数据结构定义

### 5.1 帧 / 关键帧

```cpp
// 定义位置: {file}:{line}
struct/class {FrameName} {
    // 位姿
    T_wb;                    // 世界坐标系下的位姿 (Pose)
    
    // 时间戳
    double timestamp;         // 时间戳
    
    // 特征点
    vector<Feature> features; // 该帧观测到的特征点
    
    // IMU 数据 (如果有)
    vector<IMUData> imu_msgs; // 两帧之间的 IMU 测量序列
};
```

### 5.2 特征点 / 地图点

```cpp
// 定义位置: {file}:{line}
struct/class {FeatureName} {
    int id;                  // 特征 ID
    Vector3d position;       // 3D 位置 (世界系)
    double inv_depth;        // 逆深度 (如果使用逆深度参数化)
    vector<Observation> observations; // 观测记录 (帧ID + 像素坐标)
};
```

### 5.3 预积分量

```cpp
// 定义位置: {file}:{line}
class IntegrationBase {
public:
    // 预积分结果
    Vector3d delta_p_;       // 位置增量 α_ij
    Vector3d delta_v_;       // 速度增量 β_ij
    Quaterniond delta_q_;    // 旋转增量 γ_ij
    
    // 雅可比矩阵
    Matrix3d jac_a_;         // ∂Δ/∂ba
    Matrix3d jac_g_;         // ∂Δ/∂bg
    
    // 协方差
    Matrix<double, 15,15> covariance_;
    
private:
    // 原始数据缓存
    vector<double> vdt_;
    vector<Vector3d> vacc_;
    vector<Vector3d> vgyr_;
};
```

### 5.4 其他核心结构

（按需添加：滑动窗口、状态服务器、因子定义等）

**汇总表**：

| 结构名 | 定义位置 | 主要成员 | 用途 |
|--------|---------|---------|------|
| `{StructName}` | `{file}:{line}` | `{members}` | {一句话} |
| ... | ... | ... | ... |

---

## 6. 线程间通信方式

| 数据名称 | 发送方模块 | 接收方模块 | 通信机制 | 缓冲区/队列 | 同步方式 |
|---------|-----------|-----------|---------|------------|---------|
| `{image_data}` | Frontend | Backend | `queue<ImageData>` | 最大 N 帧 | mutex + condition_variable |
| `{imu_data}` | IMU Handler | Integrator | `vector<IMUData>` | 按时间窗口 | mutex |
| `{odometry_result}` | Backend | Viewer | `shared_ptr<Odometry>` | 最新一帧 | atomic |

---

## 7. 数据融合点

以下位置发生了多传感器数据的联合处理：

| # | 融合位置 | 文件:行号 | 融合方式 | 参与传感器 | 输出 |
|---|---------|-----------|---------|-----------|------|
| 1 | `{function_name}` | `{f}:{l}` | {紧耦合/松耦合} | Visual + IMU | {输出} |
| 2 | ... | ... | ... | ... | ... |

---

## 8. 待确认项

| # | 不确定项 | 所在位置 | 原因 | 建议验证方式 |
|---|---------|---------|------|-------------|
| 1 | `{what}` | `{where}` | `{why}` | {how} |
