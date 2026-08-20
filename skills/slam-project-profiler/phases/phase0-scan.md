# Phase 0: 自动扫描

## 目标

在不打扰用户的前提下，尽可能多地从项目目录、配置文件、源码中自动提取信息，形成初步假设。为 Phase 1 的交互确认提供素材。

## 触发词

- "扫描项目结构"
- "分析项目"

## 依赖

无

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_path | string | ✅ | 项目根目录绝对路径 |

## 输出产物

不生成文件，但产出一组**待确认假设清单**，供 Phase 1 使用。

## 执行步骤

### Step 1: 扫描项目骨架

**1.1 目录结构**

递归列出项目目录树（深度 ≤ 3 层），排除以下目录：
```
.git/ build/ __pycache__/ *.egg-info/ node_modules/ .vscode/ .idea/
```

**1.2 文件类型统计**

按扩展名统计源文件数量：
- C++: `.cpp`, `.h`, `.hpp`, `.cc`, `.cxx`, `.cu`, `.cuh`
- Python: `.py`
- 配置: `.yaml`, `.yml`, `.json`, `.xml`, `.launch`, `.cfg`, `.ini`, `.conf`
- 文档: `.md`, `.txt`, `.rst`
- 脚本: `.sh`, `.bat`, `.py`（在 `scripts/` 或 `tools/` 下）

**1.3 识别构建系统**

检查是否存在：
- `CMakeLists.txt` → CMake
- `package.xml` → ROS/ Catkin
- `setup.py` / `pyproject.toml` → Python
- `Makefile` → Make
- `colcon.meta` → ROS2/ Colcon

### Step 2: 读取项目文档

按优先级读取以下内容：
1. `README.md` / `README_CN.md` / `README.txt`
2. `INSTALL.md` / `BUILD.md`
3. `docs/` 目录下的文档
4. 项目 Wiki 链接（如果 README 中有）

从文档中提取：
- 项目名称和简介
- 支持的传感器类型（相机、IMU、LiDAR）
- 支持的数据集列表
- 运行方式说明
- 配置文件说明
- 评估方法说明

### Step 3: 分析配置文件

**3.1 传感器配置**

搜索并读取配置文件（`.yaml`, `.json`, `.xml`），识别：
- 相机内参（`fx`, `fy`, `cx`, `cy`, `distortion`, `K`）
- IMU 参数（`noise`, `bias`, `gravity`）
- 外参（`T_cam_imu`, `extrinsic`, `calib`）
- 传感器数量（单目/双目/多相机）

**3.2 运行参数**

搜索 launch 文件或启动脚本，识别：
- 数据集路径参数
- 输出目录参数
- 日志级别/路径参数

### Step 4: 识别数据集与真值

**4.1 数据目录**

检查项目根目录的上级/同级目录，或 README 中提到的数据路径。
如果项目自带示例数据，记录其格式。

**4.2 真值格式推断**

在代码中搜索以下关键词，推断真值格式：
```
# 真值加载相关
groundtruth, ground_truth, gt_file, truth_file
loadTrajectory, readGroundTruth, loadGT
TUM, EuRoC, KITTI
timestamp tx ty tz, "timestamp,tx,ty,tz"
```

如果找到加载代码，读取具体实现，记录：
- 支持的格式（TUM / EuRoC / KITTI / 自定义）
- 列含义
- 时间戳单位

**4.3 轨迹输出格式推断**

搜索轨迹输出相关代码：
```
# 轨迹保存相关
saveTrajectory, writeTrajectory, saveResult, output_traj
saveKeyFrameTrajectory, writeKeyFrameTrajectories
TUM, EuRoC, KITTI
```

如果找到输出代码，记录输出格式和文件路径约定。

### Step 5: 识别日志体系

**5.1 日志框架**

搜索代码中的日志调用：
```
# 日志关键词
LOG_, log_, ROS_INFO, ROS_WARN, ROS_ERROR, ROS_DEBUG
spdlog, glog, cout, cerr, fprintf
VLOG_, DVLOG_
```

判断项目使用的日志框架：
- `ROS_INFO/WARN/ERROR` → ROS 日志
- `LOG(INFO)` / `LOG(WARNING)` → glog
- `spdlog::info` → spdlog
- `std::cout` / `printf` → 无框架
- 自定义宏 → 分析宏定义

**5.2 日志格式推断**

从代码中提取日志格式模式：
```cpp
// 示例: ROS_INFO("[Frontend] Tracked %d features", n);
// → 格式: [模块名] 内容
```

识别日志中是否包含：
- 时间戳
- 日志级别
- 模块名
- 文件名:行号

**5.3 关键日志条目**

搜索高频日志输出，记录其含义：
```
# 高频输出模式
tracked.*features, inliers, cost, residual, status
optimization, converged, diverged, lost, relocalization
```

### Step 6: 识别评估方式

**6.1 评估脚本**

搜索项目中的评估相关脚本：
```
scripts/eval*, tools/evaluate*, benchmark*, compare*, analyze*
*.py (包含 eval, metric, error, ATE, RPE 等关键词)
```

**6.2 评估指标**

在代码或文档中搜索指标关键词：
```
ATE, RPE, RMSE, mean error, max error, accuracy
trajectory error, pose error, translation error, rotation error
```

### Step 7: 识别构建配置

**7.1 构建系统详情**

读取 `CMakeLists.txt`（或 `Makefile` / `package.xml`），提取：
- CMake 最低版本要求
- C++ 标准（C++11/14/17/20）
- 编译选项（`-O2`, `-g`, `-march=native` 等）
- 构建类型（Debug/Release/RelWithDebInfo）

**7.2 构建目录**

搜索常见的构建目录：
```
build/, bin/, lib/, .build/
```

检查是否存在已构建的文件（可执行文件、库文件）。

**7.3 构建命令**

从 README 或文档中提取构建命令：
```bash
# 常见模式
mkdir build && cd build && cmake .. && make
catkin build / catkin_make
colcon build
```

**7.4 依赖检查**

从 `CMakeLists.txt` 的 `find_package` 和 `package.xml` 的 `<depend>` 提取依赖：
- 系统依赖（OpenCV, Eigen, PCL 等）
- ROS 包依赖（如果是 ROS 项目）
- 第三方库依赖

**7.5 构建选项**

从 `CMakeLists.txt` 的 `option()` 和 `set()` 提取可配置选项：
```cmake
option(USE_CUDA "Enable CUDA support" OFF)
set(MAX_FEATURES 200 CACHE STRING "Maximum number of features")
```

**7.6 构建产物**

从 `CMakeLists.txt` 的 `add_executable` 和 `add_library` 提取：
- 可执行文件名称和路径
- 库文件名称和路径

### Step 8: 识别运行配置

**8.1 可执行文件**

从构建产物或代码中识别主可执行文件：
- `main()` 函数所在文件
- `add_executable` 定义的目标
- launch 文件中的节点

**8.2 运行命令**

从 README、launch 文件或脚本中提取运行命令：
```bash
# 独立运行
./build/slam_system --config config.yaml --dataset /path/to/data

# ROS 运行
roslaunch package_name launch_file.launch
```

**8.3 配置文件**

搜索项目中的配置文件：
```
config/*.yaml, config/*.json, config/*.xml
*.cfg, *.ini, *.conf
```

记录配置文件路径和用途。

**8.4 命令行参数**

从代码中的参数解析（`argc/argv`, `getopt`, `gflags`, `ROS parameters`）提取：
- 参数名称
- 参数类型
- 默认值
- 参数说明

**8.5 环境变量**

搜索代码中的环境变量使用：
```cpp
getenv("VAR_NAME")
std::getenv("VAR_NAME")
$ENV{VAR_NAME}  # CMake
```

**8.6 运行时依赖**

识别运行时需要的：
- 数据文件（相机标定、词袋模型等）
- 动态库
- 网络服务

**8.7 性能优化设置**

从配置文件或代码中提取性能相关参数：
```
# 常见性能参数
num_threads, thread_pool_size
batch_size, buffer_size
max_iterations, convergence_threshold
enable_optimization, use_gpu
```

### Step 9: 识别可调参数

**9.1 参数配置文件**

搜索项目中的配置文件：
```
config/*.yaml, config/*.json, config/*.xml
*.cfg, *.ini, *.conf
params/*.yaml, settings/*.yaml
```

读取配置文件，提取所有可配置参数。

**9.2 代码中的参数定义**

在源代码中搜索参数定义：
```cpp
// C++ 参数定义模式
double param_name = 1.0;
int max_features = 200;
constexpr double THRESHOLD = 0.01;

// ROS 参数
nh.param("param_name", value, default_value);
nh.getParam("param_name", value);

// 配置类
struct Config {
    double param1;
    int param2;
};
```

**9.3 参数范围分析**

从代码中提取参数的使用方式和约束：
- 参数的物理意义
- 参数的合理范围
- 参数之间的依赖关系
- 参数对性能的影响

**9.4 参数文档**

检查是否有参数说明文档：
```
docs/parameters.md
README.md 中的参数说明
config/README.md
```

### Step 10: 生成假设清单

将以上所有发现整理为**待确认假设清单**，格式如下：

```markdown
## Phase 0 扫描结果 — 待确认假设

### 项目基本信息
- [假设] 项目名称: {name}
- [假设] 框架: ROS1 / ROS2 / 独立运行
- [假设] 语言: C++ / Python

### 数据集
- [假设] 数据目录: {path}
- [假设] 数据集格式: TUM / EuRoC / KITTI / 自定义
- [假设] 传感器: 单目+IMU / 双目+IMU / ...

### 真值
- [假设] 真值文件: {path}
- [假设] 格式: TUM (timestamp tx ty tz qx qy qz qw) / ...
- [假设] 时间戳单位: 秒 / 纳秒

### 系统输出
- [假设] 轨迹文件: {path}
- [假设] 格式: TUM / EuRoC / 自定义
- [假设] 输出目录: {path}

### 日志
- [假设] 日志框架: ROS / glog / spdlog / cout
- [假设] 日志目录: {path}
- [假设] 日志格式: [时间戳] [级别] [模块] 内容

### 评估
- [假设] 评估脚本: {path}
- [假设] 运行方式: {command}
- [假设] 关注指标: ATE RMSE / ...

### 构建配置
- [假设] 构建系统: CMake / Catkin / Colcon
- [假设] C++ 标准: C++11 / C++14 / C++17
- [假设] 构建目录: {path}
- [假设] 构建命令: {command}
- [假设] 主要依赖: OpenCV, Eigen, ...
- [假设] 可执行文件: {path}

### 运行配置
- [假设] 可执行文件: {path}
- [假设] 运行命令: {command}
- [假设] 配置文件: {path}
- [假设] 命令行参数: --config, --dataset, ...
- [假设] 性能参数: num_threads=4, ...

### 可调参数
- [假设] 参数配置文件: {path}
- [假设] 关键参数: max_features=200, min_inliers=10, ...
- [假设] 参数范围: max_features=[100,500], ...
- [假设] 参数依赖: {参数A} 增大时 {参数B} 也需要调整
- [假设] 参数灵敏度: max_features(高), min_inliers(中), ...
```

## 注意事项

1. **只读操作**：Phase 0 不修改任何文件，只做读取和分析
2. **大胆假设**：宁可多提出假设让 Phase 1 确认，也不要遗漏
3. **标注信息来源**：每个假设标注是从哪里推断的（哪个文件/哪行代码/哪个文档）
4. **标注置信度**：对每个假设标注置信度（高/中/低）
   - 高：代码中有明确定义或文档中有明确说明
   - 中：根据命名惯例或上下文推断
   - 低：纯猜测，需要用户确认
