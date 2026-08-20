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

### Step 7: 生成假设清单

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
```

## 注意事项

1. **只读操作**：Phase 0 不修改任何文件，只做读取和分析
2. **大胆假设**：宁可多提出假设让 Phase 1 确认，也不要遗漏
3. **标注信息来源**：每个假设标注是从哪里推断的（哪个文件/哪行代码/哪个文档）
4. **标注置信度**：对每个假设标注置信度（高/中/低）
   - 高：代码中有明确定义或文档中有明确说明
   - 中：根据命名惯例或上下文推断
   - 低：纯猜测，需要用户确认
