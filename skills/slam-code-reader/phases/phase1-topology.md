# Phase 1: 代码拓扑扫描

## 目标

建立"目录结构 → 模块职责"映射表。不读实现细节，只看骨架：编译目标、依赖关系、入口点、线程模型。

## 触发词

- "扫描拓扑"
- "看一下架构"
- "分析目录结构"
- "梳理代码骨架"

## 依赖

无（可作为第一个执行的 Phase）

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| repo_path | string | ✅ | 仓库根目录绝对路径 |

## 输出产物

```
{仓库名}-code-analysis/
└── 01_拓扑结构分析.md
```

## 执行步骤

### Step 1: 扫描源文件分布

使用 Glob 扫描以下类型的文件：
- C++: `*.cpp`, `*.h`, `*.hpp`, `*.cu`, `*.cuh`, `*.c`
- Python: `*.py`
- 配置: `CMakeLists.txt`, `package.xml`, `*.yaml`, `*.yml`, `*.launch`

**统计信息**：
- 各语言文件数量
- 按目录的文件分布
- 总代码行数估算（排除 third_party/, test/, example/, benchmark/）

### Step 2: 分析构建系统

**2.1 CMakeLists.txt 分析（递归查找所有层级）**

提取：
```cmake
# 编译目标
add_executable(...)     → 可执行文件（入口候选）
add_library(...)        → 库文件
add_subdirectory(...)   → 子模块划分

# 依赖关系
find_package(...)       → 外部依赖（OpenCV, Eigen, Ceres, g2o...）
target_link_libraries(...) → 链接关系

# 编译选项
set(CMAKE_CXX_STANDARD ...) → C++ 标准
add_definitions(-D...)      → 预处理宏
```

**2.2 ROS 工程额外分析**
- 读取 `package.xml` 提取 `<depend>` 标签
- 遍历 `launch/` 目录，记录节点启动方式
- 识别话题名称（从 launch 文件或源码中的 subscribe/publish）

### Step 3: 定位入口点

搜索 `int main(` 的位置：
- 记录每个 main 函数的文件路径和行号
- 判断哪个是主入口（通常在可执行文件对应的源码中）
- 如果是 ROS 节点，入口可能是 `ros::init()` 后的回调注册

### Step 4: 识别线程/节点模型

搜索以下关键词：

| 关键词 | 含义 |
|--------|------|
| `std::thread`, `std::async` | C++ 原生线程 |
| `ros::spin()`, `ros::Spin()` | ROS 单线程循环 |
| `ros::AsyncSpinner` | ROS 多线程 |
| `pthread_create` | POSIX 线程 |
| `boost::thread` | Boost 线程 |
| `std::mutex`, `std::lock_guard` | 线程同步（间接证明多线程） |

记录每个线程的创建位置和推测职责。

### Step 5: 推断模块职责

根据 **目录命名 + 文件命名 + 内容抽样**，推断每个顶级/二级目录的职责。

**SLAM 代码常见模式参考表**：

| 目录名/文件名模式 | 通常职责 |
|-----------------|---------|
| `feature_tracker/`, `frontend/`, `tracking/` | 前端：特征提取与跟踪 |
| `estimator/`, `backend/`, `optimizer/` | 后端：优化求解 |
| `initial/`, `initializer/`, `init_*` | 初始化模块 |
| `factor/`, `cost_function/` | 残差因子/代价函数定义 |
| `integration/`, `preintegration/` | IMU 预积分 |
| `marginalization/`, `margi*` | 边缘化 / Schur 补 |
| `loop/`, `loop_closing/`, `pose_graph/` | 回环检测 / 位姿图 |
| `camera/`, `cam_model/` | 相机模型 |
| `map/`, `landmark/`, `mappoint/` | 地图点管理 |
| `viewer/`, `visualizer/`, `ui/` | 可视化 |
| `utility/`, `tool/`, `utils/`, `common/` | 工具类 |
| `config/`, `param/`, `yaml/` | 配置 |
| `sensor/`, `imu/` | 传感器接口/数据处理 |

> ⚠️ 以上是经验规律，不能硬套。如果某个目录无法确定，标注"待确认"。

### Step 6: 生成报告

套用 `templates/topology-report-template.md` 格式，输出包含以下章节的 Markdown：

```markdown
# 01_拓扑结构分析

> 仓库: {仓庛名} | 生成日期: {日期}

## 1. 项目概览
   - 语言/框架/构建系统
   - 文件统计 (各类型数量)
   - 代码量估算 (排除第三方)

## 2. 目录结构树
   (折叠 third_party/, test/, .git/ 等)
   每个目录旁标注推断的职责

## 3. 模块职责映射表
   | 目录 | 职责 | 置信度 | 关键文件 |

## 4. 构建系统分析
   - 编译目标列表 (可执行文件/库)
   - 外部依赖列表
   - 子模块划分

## 5. 入口点
   - main 函数位置
   - 启动流程简述

## 6. 线程/节点模型
   - 线程数及各自职责
   - 线程间通信方式 (队列/共享变量/callback)

## 7. 待确认项
   - 无法确定的模块/机制，列出供后续 Phase 验证
```

## 注意事项

1. **不深入实现**：本 Phase 只看"骨架"，不读函数体内部逻辑
2. **明确标注不确定项**：宁可写"待确认"也不要猜测
3. **大型仓库处理**：如果文件数 > 500，优先扫描核心目录，跳过 third_party/ 和 test/
4. **ROS 工程**：额外关注 topic 名称和消息类型，这对 Phase 2 数据流追踪很关键
