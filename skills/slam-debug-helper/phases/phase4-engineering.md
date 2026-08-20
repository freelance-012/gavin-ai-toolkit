# Phase 4: 工程调试

## 目标

处理系统级问题：崩溃、内存问题、性能瓶颈、线程问题等。这些问题通常需要通过调试工具（gdb、valgrind、perf）和系统日志来诊断。

## 触发词

- "系统崩溃了"
- "段错误"
- "内存泄漏"
- "程序卡死"
- "CPU 占用过高"
- "实时性不够"

## 依赖

Phase 0-3（可选，如果算法层面无问题则直接进入 Phase 4）

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| issue_type | string | ✅ | 工程问题类型（crash/memory/perf/thread） |
| core_dump | string | ⬜ | core dump 文件路径（如果有） |
| error_log | string | ⬜ | 错误日志路径（如果有） |

## 输出产物

```
{project}/.specs/debug/{timestamp}_{session_id}/
├── engineering-debug-report.md    # 工程调试报告
└── fix-suggestions-engineering.md # 工程修复方案
```

## 执行步骤

### Step 1: 问题分类

根据用户描述，确定工程问题类型：

#### 1.1 系统崩溃（Crash）

**症状**:
- 段错误（Segmentation fault）
- 程序异常终止
- Core dump 生成

**诊断方法**:
```bash
# 查看 core dump
gdb {executable} {core_file}
(gdb) bt                    # 查看调用栈
(gdb) info locals           # 查看局部变量
(gdb) frame {N}             # 切换到特定帧
(gdb) print {variable}      # 打印变量值

# 如果没有 core dump，使用 gdb 实时调试
gdb --args {executable} {args}
(gdb) run
# 程序崩溃后
(gdb) bt
```

**常见原因**:
1. 空指针解引用
2. 数组越界
3. 使用已释放的内存
4. 栈溢出（递归过深或局部变量过大）
5. 类型转换错误

#### 1.2 内存问题（Memory）

**症状**:
- 内存持续增长（内存泄漏）
- 内存使用异常高
- 程序运行变慢

**诊断方法**:
```bash
# 使用 valgrind 检测内存泄漏
valgrind --leak-check=full --show-leak-kinds=all \
         --track-origins=yes --log-file=valgrind.log \
         {executable} {args}

# 使用 AddressSanitizer（编译时添加 -fsanitize=address）
cmake -DCMAKE_CXX_FLAGS="-fsanitize=address -g" ..
make
./{executable} {args}

# 实时监控内存使用
watch -n 1 "ps aux | grep {process_name} | awk '{print \$6/1024 \" MB\"}'"
```

**常见原因**:
1. new/malloc 后未 delete/free
2. 容器未清理
3. 循环引用（智能指针）
4. 缓存无限制增长
5. 第三方库内存泄漏

#### 1.3 性能问题（Performance）

**症状**:
- CPU 占用过高
- 帧率下降
- 实时性不满足

**诊断方法**:
```bash
# 使用 perf 分析 CPU 热点
perf record -g {executable} {args}
perf report

# 使用 gprof 分析函数调用
# 编译时添加 -pg
cmake -DCMAKE_CXX_FLAGS="-pg -g" ..
make
./{executable} {args}
gprof {executable} gmon.out > analysis.txt

# 查看线程 CPU 占用
top -H -p {pid}

# 查看系统调用
strace -c -p {pid}
```

**常见原因**:
1. 算法复杂度过高
2. 不必要的重复计算
3. 锁竞争（多线程）
4. 内存分配过于频繁
5. I/O 阻塞

#### 1.4 线程问题（Thread）

**症状**:
- 程序卡死（死锁）
- 数据竞争
- 线程崩溃

**诊断方法**:
```bash
# 使用 gdb 查看线程状态
gdb -p {pid}
(gdb) info threads              # 查看所有线程
(gdb) thread {N}                # 切换到特定线程
(gdb) bt                        # 查看调用栈
(gdb) thread apply all bt       # 查看所有线程的调用栈

# 使用 ThreadSanitizer 检测数据竞争
# 编译时添加 -fsanitize=thread
cmake -DCMAKE_CXX_FLAGS="-fsanitize=thread -g" ..
make
./{executable} {args}

# 查看锁的使用情况
# 在代码中添加日志或使用 mutex wrapper
```

**常见原因**:
1. 死锁（多个锁的获取顺序不一致）
2. 数据竞争（未加锁访问共享数据）
3. 线程未正确Join
4. 条件变量使用错误
5. 信号处理不当

### Step 2: 收集调试信息

根据问题类型，收集相应的调试信息：

#### 2.1 崩溃问题

```bash
# 1. 检查是否生成 core dump
ls -lh core* /var/lib/apport/coredump/

# 2. 启用 core dump（如果没有）
ulimit -c unlimited
echo "/tmp/core.%e.%p" | sudo tee /proc/sys/kernel/core_pattern

# 3. 查看系统日志
dmesg | tail -50
journalctl -u {service_name} --since "1 hour ago"

# 4. 查看程序输出
{executable} {args} 2>&1 | tee crash.log
```

#### 2.2 内存问题

```bash
# 1. 监控内存使用
for i in {1..60}; do
    ps -o pid,rss,vsz,comm -p {pid} >> memory.log
    sleep 1
done

# 2. 使用 valgrind massif 分析内存分布
valgrind --tool=massif --pages-as-heap=yes {executable} {args}
ms_print massif.out.{pid}

# 3. 查看内存映射
pmap -x {pid} | sort -nk 3
```

#### 2.3 性能问题

```bash
# 1. CPU 性能分析
perf top -p {pid}
perf stat -p {pid}

# 2. 查看系统负载
vmstat 1
iostat -x 1

# 3. 查看线程状态
pidstat -t -p {pid} 1
```

#### 2.4 线程问题

```bash
# 1. 查看线程信息
ls /proc/{pid}/task/
cat /proc/{pid}/status | grep Threads

# 2. 查看锁的状态（如果有 futex）
cat /proc/{pid}/stack

# 3. 使用 strace 查看系统调用
strace -f -e trace=futex -p {pid}
```

### Step 3: 根因分析

基于收集的信息，分析根本原因：

#### 3.1 崩溃根因分析

```
调用栈分析
├─ 崩溃位置: {file}:{line} in {function}
├─ 直接原因: {空指针/越界/...}
├─ 触发条件: {什么输入/状态导致}
└─ 根本原因: {为什么会出现这个状态}
```

#### 3.2 内存根因分析

```
内存泄漏分析
├─ 泄漏位置: {file}:{line} in {function}
├─ 泄漏类型: {new/malloc/...}
├─ 泄漏大小: {bytes}
├─ 泄漏频率: {每次/周期性/...}
└─ 根本原因: {为什么未释放}
```

#### 3.3 性能根因分析

```
性能瓶颈分析
├─ 热点函数: {function} ({percentage}%)
├─ 调用次数: {count}
├─ 单次耗时: {time}
├─ 优化空间: {算法/数据结构/缓存/...}
└─ 根本原因: {为什么这个函数是瓶颈}
```

#### 3.4 线程根因分析

```
线程问题分析
├─ 问题线程: Thread {id} ({name})
├─ 问题类型: {死锁/竞争/...}
├─ 涉及资源: {mutex/variable/...}
├─ 触发条件: {什么操作序列}
└─ 根本原因: {为什么设计上有问题}
```

### Step 4: 生成修复方案

提供具体的修复方案，包括代码修改和调试配置：

#### 4.1 崩溃修复方案

```markdown
### 修复方案: 修复 {function} 中的空指针解引用

**问题位置**: `{file}:{line}`

**问题代码**:
```cpp
void process(std::shared_ptr<Data> data) {
    data->process();  // 可能为空
}
```

**修复代码**:
```cpp
void process(std::shared_ptr<Data> data) {
    if (!data) {
        LOG(ERROR) << "data is null";
        return;
    }
    data->process();
}
```

**验证方法**:
1. 重新编译运行
2. 确认不再崩溃
3. 添加单元测试覆盖空指针情况
```

#### 4.2 内存修复方案

```markdown
### 修复方案: 修复 {class} 的内存泄漏

**问题位置**: `{file}:{line}`

**问题代码**:
```cpp
class Processor {
    std::vector<Data*> cache;
public:
    void add(Data* d) {
        cache.push_back(d);  // 未管理生命周期
    }
};
```

**修复代码**:
```cpp
class Processor {
    std::vector<std::unique_ptr<Data>> cache;
public:
    void add(std::unique_ptr<Data> d) {
        cache.push_back(std::move(d));
    }
};
```

**验证方法**:
1. 使用 valgrind 重新测试
2. 确认无内存泄漏
3. 长时间运行测试（>1小时）
```

#### 4.3 性能修复方案

```markdown
### 修复方案: 优化 {function} 的性能

**问题位置**: `{file}:{line}`

**瓶颈分析**:
- 当前复杂度: O(n²)
- 调用次数: {count}
- 占比: {percentage}%

**优化方案**:
1. 使用空间换时间（缓存计算结果）
2. 使用更高效的数据结构
3. 减少不必要的计算

**优化代码**:
```cpp
// 优化前
for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
        compute(i, j);
    }
}

// 优化后
std::unordered_map<Key, Value> cache;
for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
        Key key = make_key(i, j);
        if (cache.find(key) == cache.end()) {
            cache[key] = compute(i, j);
        }
        use(cache[key]);
    }
}
```

**验证方法**:
1. 使用 perf 重新分析
2. 确认热点函数占比下降
3. 测量帧率提升
```

#### 4.4 线程修复方案

```markdown
### 修复方案: 修复 {function} 中的死锁

**问题位置**: `{file}:{line}`

**死锁分析**:
- Thread A: 持有 lock1，等待 lock2
- Thread B: 持有 lock2，等待 lock1

**修复方案**: 统一锁的获取顺序

**修复代码**:
```cpp
// 修复前（可能死锁）
void funcA() {
    std::lock_guard<std::mutex> lock1(mut1);
    std::lock_guard<std::mutex> lock2(mut2);
    // ...
}

void funcB() {
    std::lock_guard<std::mutex> lock2(mut2);
    std::lock_guard<std::mutex> lock1(mut1);
    // ...
}

// 修复后（统一顺序）
void funcA() {
    std::lock_guard<std::mutex> lock1(mut1);
    std::lock_guard<std::mutex> lock2(mut2);
    // ...
}

void funcB() {
    std::lock_guard<std::mutex> lock1(mut1);  // 改为先获取 lock1
    std::lock_guard<std::mutex> lock2(mut2);
    // ...
}
```

**验证方法**:
1. 使用 ThreadSanitizer 测试
2. 长时间运行测试（>24小时）
3. 确认无死锁
```

### Step 5: 调试配置建议

提供调试编译配置和运行参数：

```markdown
### 调试配置建议

**CMake 配置**（启用调试工具）:
```cmake
# Debug 模式
set(CMAKE_BUILD_TYPE Debug)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -O0")

# 启用 AddressSanitizer
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=address -fno-omit-frame-pointer")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=address")

# 启用 ThreadSanitizer
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=thread")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=thread")

# 启用性能分析
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pg")
```

**运行参数**:
```bash
# 启用 core dump
ulimit -c unlimited

# 使用 gdb 调试
gdb --args {executable} {args}

# 使用 valgrind
valgrind --leak-check=full --track-origins=yes {executable} {args}

# 使用 perf
perf record -g {executable} {args}
```
```

## 注意事项

1. **调试工具依赖**: 确保系统安装了 gdb、valgrind、perf 等工具
2. **编译配置**: 调试时需要使用 Debug 模式（-g -O0）
3. **性能影响**: Sanitizer 会显著降低性能，仅用于调试
4. **Core dump 配置**: 确保系统允许生成 core dump
5. **日志级别**: 调试时启用详细日志（DEBUG 或 TRACE）
