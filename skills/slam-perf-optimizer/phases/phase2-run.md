# Phase 2: 自动运行

## 目标

自动运行 SLAM 系统，监控进程状态，捕获运行日志和输出。

## 触发词

- "运行系统"
- "run system"
- "执行 SLAM"

## 依赖

Phase 1 构建成功

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| config | json | ✅ | Phase 0 的优化配置 |
| iteration_id | int | ⬜ | 当前迭代编号 |

## 输出产物

- `{session_dir}/iterations/iter_{NNN}/run.log`
- `{session_dir}/iterations/iter_{NNN}/trajectory.txt`
- `{session_dir}/iterations/iter_{NNN}/run-result.json`

## 执行步骤

### Step 1: 准备运行环境

```bash
cd {project_path}

# 清理上一轮输出（如果有）
output_dir={run_config.output_dir}
if [ -d "$output_dir" ]; then
    # 备份旧输出
    backup_dir="${output_dir}_backup_$(date +%s)"
    mv "$output_dir" "$backup_dir"
fi

# 创建新的输出目录
mkdir -p "$output_dir"
```

### Step 2: 组装运行命令

```python
# 从配置中读取命令模板
command_template = config["run_config"]["command_template"]

# 替换占位符
run_command = command_template.format(
    executable=config["run_config"]["executable"],
    dataset=config["run_config"]["dataset"],
    config=config["run_config"]["config_file"],
    output=config["run_config"]["output_dir"]
)

log(f"运行命令: {run_command}")
```

### Step 3: 启动运行进程

```python
import subprocess
import time
from datetime import datetime

# 记录运行开始时间
start_time = time.time()
start_timestamp = datetime.now().isoformat()

# 启动进程，重定向输出到日志文件
log_file = f"{session_dir}/iterations/iter_{iteration_id:03d}/run.log"
with open(log_file, "w") as f:
    process = subprocess.Popen(
        run_command,
        shell=True,
        stdout=f,
        stderr=subprocess.STDOUT,
        cwd=project_path
    )

log(f"进程已启动 (PID: {process.pid})")
```

### Step 4: 监控进程状态

```python
timeout_sec = config["run_config"]["timeout_sec"]
check_interval = 5  # 每5秒检查一次
last_log_time = start_time
last_log_size = 0

while process.poll() is None:
    # 检查是否超时
    elapsed = time.time() - start_time
    if elapsed > timeout_sec:
        log(f"⚠️ 运行超时 ({timeout_sec}s)")
        process.terminate()
        process.wait(timeout=10)
        if process.poll() is None:
            process.kill()
        raise TimeoutError(f"运行超时: {timeout_sec}s")
    
    # 检查日志是否更新（检测卡死）
    current_log_size = os.path.getsize(log_file)
    if current_log_size > last_log_size:
        last_log_size = current_log_size
        last_log_time = time.time()
    else:
        # 日志超过 30 秒未更新，可能卡死
        if time.time() - last_log_time > 30:
            log("⚠️ 检测到可能卡死（30s 无日志输出）")
            # 继续等待，不立即终止
    
    # 显示进度
    elapsed_min = elapsed / 60
    log(f"运行中... ({elapsed_min:.1f} 分钟)", end="\r")
    
    time.sleep(check_interval)
```

### Step 5: 收集运行结果

```python
# 等待进程结束
exit_code = process.wait()
end_time = time.time()
duration = end_time - start_time

log(f"\n运行结束 (耗时: {duration:.1f}s, 退出码: {exit_code})")

# 检查输出文件
output_files = {
    "trajectory": f"{config['run_config']['output_dir']}/trajectory.txt",
    "log": log_file
}

# 检查关键输出文件是否存在
for name, path in output_files.items():
    if os.path.exists(path):
        size = os.path.getsize(path)
        log(f"✅ {name}: {path} ({size} bytes)")
    else:
        log(f"❌ {name} 缺失: {path}")
```

### Step 6: 分析运行结果

```python
run_result = {
    "iteration_id": iteration_id,
    "timestamp": start_timestamp,
    "exit_code": exit_code,
    "duration_sec": duration,
    "success": exit_code == 0,
    "output_files": output_files,
    "log_file": log_file
}

# 检查是否崩溃
if exit_code != 0:
    if exit_code == -11:  # SIGSEGV
        run_result["crash_type"] = "segmentation_fault"
        log("❌ 运行崩溃: Segmentation fault")
        
        # 检查是否有 core dump
        core_files = glob.glob("/tmp/core.*") + glob.glob("./core.*")
        if core_files:
            run_result["core_dump"] = core_files[-1]
            log(f"发现 core dump: {core_files[-1]}")
    
    elif exit_code == -6:  # SIGABRT
        run_result["crash_type"] = "abort"
        log("❌ 运行崩溃: Abort")
    
    else:
        log(f"❌ 运行失败 (退出码: {exit_code})")
    
    # 分析日志中的错误信息
    with open(log_file, "r") as f:
        log_content = f.read()
        
    # 提取错误信息
    error_lines = [line for line in log_content.split("\n") 
                   if "error" in line.lower() or "exception" in line.lower()]
    
    if error_lines:
        run_result["error_messages"] = error_lines[-5:]  # 最后5条错误
        log("\n错误信息:")
        for err in error_lines[-5:]:
            log(f"  {err}")

else:
    # 运行成功
    log("✅ 运行成功")
    
    # 检查轨迹文件
    traj_file = output_files.get("trajectory")
    if traj_file and os.path.exists(traj_file):
        # 统计轨迹点数
        with open(traj_file, "r") as f:
            line_count = sum(1 for _ in f)
        run_result["trajectory_points"] = line_count
        log(f"轨迹点数: {line_count}")
    else:
        log("⚠️ 轨迹文件缺失")
```

### Step 7: 处理运行失败

如果运行失败，提供选项：

```markdown
❌ 运行失败

退出码: {exit_code}
耗时: {duration:.1f}s

{错误信息}

请选择:
1. 调用 debug-helper 分析崩溃原因 (输入 "1")
2. 查看运行日志 (输入 "2")
3. 回退到上一轮代码 (输入 "3")
4. 退出优化 (输入 "4")
```

如果用户选择分析崩溃：
```python
if user_choice == "1":
    # 调用 debug-helper
    debug_helper = load_skill("slam-debug-helper")
    debug_helper.analyze_crash(
        core_dump=run_result.get("core_dump"),
        log_file=run_result["log_file"],
        iteration_id=iteration_id
    )
```

### Step 8: 记录运行结果

```python
# 保存到 iteration-log.json
update_iteration_log(run_result)

# 保存运行结果到单独文件
result_file = f"{session_dir}/iterations/iter_{iteration_id:03d}/run-result.json"
with open(result_file, "w") as f:
    json.dump(run_result, f, indent=2)
```

### Step 9: 运行成功输出

```markdown
✅ 运行成功

耗时: {duration:.1f}s
轨迹点数: {trajectory_points}
输出目录: {output_dir}

输出文件:
- 轨迹: trajectory.txt ({traj_size} bytes)
- 日志: run.log ({log_size} bytes)

是否继续评估？(Y/n)
```

## 错误处理

**运行超时**：
```
⚠️ 运行超时

超时时间: 300s
已运行: 300s

可能原因:
1. 数据集过大
2. 算法复杂度过高
3. 死循环

建议:
1. 增加超时时间
2. 检查算法是否有死循环
3. 使用更小的数据集测试
```

**运行崩溃**：
```
❌ 运行崩溃

退出码: -11 (Segmentation fault)
耗时: 45.2s

诊断: 内存访问错误

建议:
1. 运行 debug-helper 分析 core dump
2. 检查最近修改的代码
3. 使用 valgrind 检测内存问题
```

**输出文件缺失**：
```
⚠️ 输出文件缺失

期望: trajectory.txt
实际: 未找到

可能原因:
1. 运行未完成就退出
2. 输出路径配置错误
3. 算法提前终止

建议:
1. 检查运行日志
2. 确认输出路径配置
3. 检查算法终止条件
```

**进程卡死**：
```
⚠️ 检测到进程卡死

30 秒无日志输出

可能原因:
1. 死锁
2. 无限循环
3. 等待外部输入

建议:
1. 终止进程并分析
2. 检查线程同步逻辑
3. 检查是否有阻塞调用
```

## 注意事项

1. **超时设置**：根据数据集大小合理设置超时时间
2. **日志监控**：实时监控日志输出，检测卡死
3. **Core dump**：启用 core dump 以便崩溃分析
4. **输出备份**：每轮运行的输出独立保存，避免覆盖
5. **进程清理**：确保异常退出时正确清理进程
6. **资源监控**：监控 CPU/内存使用，防止资源耗尽
7. **信号处理**：正确处理 SIGTERM/SIGINT，优雅退出
