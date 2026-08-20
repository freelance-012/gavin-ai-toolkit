# Phase 0: 初始化

## 目标

读取 project-spec.md，检查依赖 skill 和配置，初始化优化会话。

## 触发词

- "初始化优化"
- "init optimization"

## 依赖

- `slam-project-profiler`：已生成 project-spec.md

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_path | string | ✅ | 项目根目录绝对路径 |
| max_iterations | int | ⬜ | 最大迭代次数（默认 10） |
| target_metric | string | ⬜ | 目标指标（如 "ate_rmse < 0.1"） |

## 输出产物

- `{project}/.specs/optimization/{timestamp}_{session_id}/optimization-config.json`

## 执行步骤

### Step 1: 检查 project-spec.md

```python
spec_path = f"{project_path}/.specs/project-spec.md"
if not exists(spec_path):
    error("缺少 project-spec.md，请先运行 slam-project-profiler")
```

### Step 2: 解析必需配置

从 project-spec.md 提取：

**构建配置**：
- 构建系统（CMake/Catkin/Colcon）
- 构建目录
- 构建命令
- 依赖列表

**运行配置**：
- 可执行文件路径
- 数据集路径
- 参数文件路径
- 运行命令模板
- 输出目录
- 超时时间

**评估配置**：
- 真值文件路径
- 评估脚本路径
- 评估命令模板

### Step 3: 验证配置完整性

```python
required_fields = [
    "build_system", "build_dir", "build_command",
    "executable", "dataset_path", "config_file",
    "run_command_template", "output_dir",
    "gt_file", "eval_script", "eval_command"
]

missing = [f for f in required_fields if f not in spec]
if missing:
    error(f"project-spec.md 缺少必需配置: {missing}")
```

### Step 4: 检查依赖 skill

```python
required_skills = [
    "slam-eval-runner",
    "slam-log-analyzer",
    "slam-debug-helper"
]

for skill in required_skills:
    if not skill_exists(skill):
        warn(f"依赖 skill 缺失: {skill}，部分功能可能不可用")
```

### Step 5: 检查数据集和真值

```python
if not exists(spec["dataset_path"]):
    error(f"数据集不存在: {spec['dataset_path']}")

if not exists(spec["gt_file"]):
    error(f"真值文件不存在: {spec['gt_file']}")
```

### Step 6: 创建优化会话目录

```python
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
session_id = generate_session_id()
session_dir = f"{project_path}/.specs/optimization/{timestamp}_{session_id}"
mkdir_p(session_dir)
mkdir_p(f"{session_dir}/iterations")
```

### Step 7: 生成 optimization-config.json

```json
{
  "version": "1.0",
  "project": "sf_slam",
  "project_path": "/path/to/project",
  "session_id": "abc123",
  "timestamp": "2026-08-20T14:00:00Z",
  "max_iterations": 10,
  "target_metric": "ate_rmse < 0.1",
  "auto_apply": false,
  "build_config": {
    "system": "cmake",
    "build_dir": "./build",
    "command": "cmake .. && make -j4",
    "dependencies": ["OpenCV", "Eigen", "Ceres"]
  },
  "run_config": {
    "executable": "./bin/slam_system",
    "dataset": "/path/to/dataset",
    "config": "./config/params.yaml",
    "command_template": "{executable} --dataset {dataset} --config {config}",
    "output_dir": "./output",
    "timeout_sec": 300
  },
  "eval_config": {
    "gt_file": "/path/to/groundtruth.txt",
    "eval_script": "./scripts/evaluate.py",
    "command_template": "python {script} --traj {output}/trajectory.txt --gt {gt}"
  }
}
```

### Step 8: 输出初始化报告

```markdown
✅ 优化会话初始化完成

📋 配置信息:
- 项目: sf_slam
- 会话 ID: abc123
- 最大迭代: 10 轮
- 目标指标: ate_rmse < 0.1
- 自动应用: false (需用户确认)

🔨 构建配置:
- 系统: CMake
- 命令: cmake .. && make -j4
- 依赖: OpenCV, Eigen, Ceres

🏃 运行配置:
- 可执行文件: ./bin/slam_system
- 数据集: /path/to/dataset
- 超时: 300 秒

📊 评估配置:
- 真值: /path/to/groundtruth.txt
- 脚本: ./scripts/evaluate.py

✅ 所有检查通过

是否开始优化？(Y/n)
```

## 错误处理

**缺少 project-spec.md**：
```
❌ 缺少 project-spec.md

路径: {project}/.specs/project-spec.md

解决方案:
1. 运行 slam-project-profiler 生成 spec
2. 或手动创建 spec 文件

是否运行 profiler？(Y/n)
```

**缺少必需配置**：
```
❌ project-spec.md 缺少必需配置

缺失项:
- build_command
- run_command_template

解决方案:
1. 编辑 {project}/.specs/project-spec.md
2. 添加缺失的配置项
3. 重新运行 optimizer
```

**数据集不存在**：
```
❌ 数据集不存在

路径: /path/to/dataset

解决方案:
1. 检查数据集路径是否正确
2. 下载或准备数据集
3. 更新 project-spec.md 中的 dataset_path
```
