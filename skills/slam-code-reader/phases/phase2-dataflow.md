# Phase 2: 数据流追踪

## 目标

从传感器原始输入到位姿输出，追踪完整数据 pipeline。识别每个数据变换节点：对应的类、函数、输入输出数据结构。

## 触发词

- "追踪数据流"
- "分析 pipeline"
- "数据怎么流转的"
- "梳理数据链路"

## 依赖

**必需**: `01_拓扑结构分析.md`（需要模块职责映射和入口点信息）

**检查逻辑**：
```
如果 {仓库名}-code-analysis/01_拓扑结构分析.md 不存在:
    → 停止，提示用户先执行 Phase 1
```

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| repo_path | string | ✅ | 仓库根目录绝对路径 |

## 输出产物

```
{仓库名}-code-analysis/
└── 02_数据流追踪.md
```

## 执行步骤

### Step 1: 确定传感器输入类型

根据 Phase 1 的结果 + 源码搜索，确定系统接收哪些传感器数据：

**搜索关键词**：

| 数据类型 | 订阅关键词 | 读取关键词 |
|---------|-----------|-----------|
| 图像 | `subscribe`, `image_callback`, `ImageConstPtr` | `cv::imread`, `VideoCapture` |
| IMU | `imu_callback`, `ImuConstPtr`, `subscribe("imu")` | 读取 IMU 文件 (.dat, .csv) |
| 深度 | `depth_callback`, `DepthImage` | - |
| 点云 | `PointCloud2`, `pointcloud_callback` | `.pcd`, `.ply` |
| GPS/GNSS | `NavSatFix`, `gps_callback` | - |
| 轮速计 | `WheelOdometry` | - |

记录每种数据的：
- 订阅/读取位置（文件名:行号）
- 回调函数签名
- 消息类型或数据格式

### Step 2: 追逐每条数据流处理链路

对每种传感器数据，从入口开始逐步追踪：

#### 2.1 Image 数据流

```
图像订阅/读取
  → 预处理 (去畸变? 尺寸调整? 色彩转换?)
    → 特征提取 (FAST/ORB/SIFT/SURF/Grid/SuperPoint?)
      → 特征跟踪 (KLT/Lucas-Kanade/光流法/描述子匹配?)
        → 去除外点 (RANSAC/Fundamental?)
          → 送入后端 (作为观测约束)
```

对每个节点记录：
- 类名和方法名
- 文件路径:行号范围
- 输入数据结构
- 输出数据结构

#### 2.2 IMU 数据流

```
IMU 订阅/读取
  → 预处理 (去偏置? 坐标系变换?)
    → 预积分 (IntegrationBase::push_back?)
      → 积分累积 (中点积分/RK4?)
        → 送入后端 (作为 IMU 因子)
```

#### 2.3 其他传感器数据流（如果有）

同理追踪 LiDAR、GPS、轮速计等。

### Step 3: 识别核心数据结构

搜索 `struct` 和 `class` 定义，重点关注在数据流中传递的容器：

**SLAM 核心数据结构参考表**：

| 数据结构 | 常见名称 | 通常包含 |
|---------|---------|---------|
| 帧/关键帧 | `Frame`, `KeyFrame`, `ImageData` | 位姿、时间戳、特征点、IMU 数据 |
| 特征点 | `Feature`, `MapPoint`, `Corner` | 3D坐标、描述子、观测帧、逆深度 |
| 预积分量 | `IntegrationBase`, `IMUPreintegrator` | alpha/beta/gamma, bias, 雅可比, 协方差 |
| 滑动窗口 | `Window`, `FrameBuffer`, `SlideWindow` | 帧列表、管理策略 |
| 窗口状态 | `StateServer`, `EstimatorState` | 所有待优化变量当前值 |
| 因子/残差 | `ResidualBlock`, `Factor`, `CostFunction` | 残差计算、雅可比 |

对每个核心数据结构记录：
- 定义位置（文件:行号）
- 关键成员变量
- 在哪个 Phase 的产出中被使用

### Step 4: 识别线程间通信方式

根据 Phase 1 识别出的线程模型，确定线程间如何传递数据：

| 方式 | 识别特征 |
|------|---------|
| 消息队列 | `queue`, `buffer`, `std::deque` + mutex |
| 共享变量 | 全局/类成员变量 + atomic/mutex |
| 回调/事件 | `callback`, `observer`, `signal/slot` |
| ROS Topic | `publish`, `advertise`, `subscriber` |

### Step 5: 生成报告

套用 `templates/dataflow-report-template.md` 格式：

```markdown
# 02_数据流追踪

> 仓库: {仓库名} | 生成日期: {日期}

## 1. 传感器输入总览
   | 传感器 | 类型 | 接口方式 | 话题/文件 | 回调位置 |

## 2. Image 数据流
   ### 2.1 完整处理链路图 (ASCII 或文字描述)
   ### 2.2 各节点详情表
      | 步骤 | 函数 | 文件:行号 | 输入 | 输出 | 备注 |

## 3. IMU 数据流
   (同上格式)

## 4. 其他传感器数据流 (如有)

## 5. 核心数据结构定义
   | 结构名 | 定义位置 | 成员变量 | 用途 |

## 6. 线程间通信方式
   | 数据 | 发送方 | 接收方 | 通信机制 | 缓冲区大小(如有) |

## 7. 数据融合点
   哪些地方发生了多传感器数据融合（视觉+IMU 等）
```

## 注意事项

1. **沿着调用链走**：不要跳步，确保每一步的输入输出能衔接上
2. **区分接口与实现**：虚函数/接口只记录声明处，实现在具体子类中找
3. **ROS 工程特别关注**：message_filters 的 TimeSynchronizer / ApproximateTime 策略影响数据同步方式
4. **不确定时标注**：某个节点的具体作用如果不明确，标注"疑似: XXX"，留给 Phase 3/4 验证
