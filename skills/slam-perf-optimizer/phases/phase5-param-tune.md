# Phase 5: 参数调优

## 目标

基于 project-spec 中的可调参数，使用系统化的搜索策略（grid/random/bayesian）找到最优参数组合，最大化系统性能。

## 触发词

- "参数调优"
- "自动调参"
- "搜索最优参数"

## 依赖

Phase 2 的首次运行结果（baseline）

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| config | json | ✅ | Phase 0 的优化配置 |
| baseline_metrics | object | ✅ | Phase 2 的首次运行指标 |
| strategy | string | ⬜ | 调优策略：grid / random / bayesian（默认 bayesian） |
| budget | int | ⬜ | 评估次数上限（默认 50） |

## 输出产物

- `{session_dir}/param-tuning/param-tuning-config.json` - 调优配置
- `{session_dir}/param-tuning/trials.json` - 所有试验记录
- `{session_dir}/param-tuning/best-params.json` - 最优参数
- `{session_dir}/param-tuning/optimization-curve.png` - 优化曲线（可选）

## 执行步骤

### Step 1: 读取可调参数

从 project-spec.md 的 `## 9. 可调参数` 章节读取：

```yaml
关键参数列表:
  - name: max_features
    current: 200
    range: [100, 500]
    type: int
    description: 每帧最大特征点数
    impact: 精度/速度权衡
  
  - name: min_inliers
    current: 10
    range: [5, 20]
    type: int
    description: RANSAC 最小内点数
    impact: 鲁棒性

参数依赖:
  - "max_features 增大时，min_inliers 也应适当增大"

参数灵敏度:
  - max_features: 高
  - min_inliers: 中
```

### Step 2: 定义参数空间

将参数转换为优化算法可用的参数空间：

```python
param_space = {
    'max_features': {
        'type': 'int',
        'range': [100, 500],
        'current': 200
    },
    'min_inliers': {
        'type': 'int',
        'range': [5, 20],
        'current': 10
    }
}
```

### Step 3: 选择调优策略

#### 3.1 Grid Search（网格搜索）

**适用场景**：
- 参数数量少（1-3 个）
- 参数范围小
- 需要全面搜索

**实现**：
```python
def grid_search(param_space, budget):
    # 根据预算均匀分割参数空间
    param_grids = {}
    for name, spec in param_space.items():
        if spec['type'] == 'int':
            n_points = min(int(budget ** (1/len(param_space))), 
                          spec['range'][1] - spec['range'][0] + 1)
            param_grids[name] = np.linspace(
                spec['range'][0], 
                spec['range'][1], 
                n_points, 
                dtype=int
            ).tolist()
        elif spec['type'] == 'float':
            n_points = int(budget ** (1/len(param_space)))
            param_grids[name] = np.linspace(
                spec['range'][0], 
                spec['range'][1], 
                n_points
            ).tolist()
    
    # 生成所有组合
    from itertools import product
    param_names = list(param_grids.keys())
    param_values = list(param_grids.values())
    
    trials = []
    for values in product(*param_values):
        trial = dict(zip(param_names, values))
        trials.append(trial)
    
    return trials[:budget]
```

#### 3.2 Random Search（随机搜索）

**适用场景**：
- 参数数量较多
- 参数范围大
- 快速探索

**实现**：
```python
def random_search(param_space, budget):
    trials = []
    for _ in range(budget):
        trial = {}
        for name, spec in param_space.items():
            if spec['type'] == 'int':
                trial[name] = random.randint(spec['range'][0], spec['range'][1])
            elif spec['type'] == 'float':
                trial[name] = random.uniform(spec['range'][0], spec['range'][1])
        trials.append(trial)
    return trials
```

#### 3.3 Bayesian Optimization（贝叶斯优化）

**适用场景**：
- 评估成本高（每次运行耗时长）
- 需要高效搜索
- 参数数量适中（2-10 个）

**实现**：
```python
from skopt import gp_minimize
from skopt.space import Integer, Real

def bayesian_optimization(param_space, evaluate_fn, budget):
    # 定义搜索空间
    dimensions = []
    for name, spec in param_space.items():
        if spec['type'] == 'int':
            dimensions.append(Integer(spec['range'][0], spec['range'][1], name=name))
        elif spec['type'] == 'float':
            dimensions.append(Real(spec['range'][0], spec['range'][1], name=name))
    
    # 目标函数（最小化误差）
    def objective(params):
        param_dict = dict(zip([d.name for d in dimensions], params))
        metric = evaluate_fn(param_dict)
        return metric
    
    # 运行贝叶斯优化
    result = gp_minimize(
        objective,
        dimensions,
        n_calls=budget,
        random_state=42,
        verbose=True
    )
    
    # 提取最优参数
    best_params = dict(zip([d.name for d in dimensions], result.x))
    best_metric = result.fun
    
    return best_params, best_metric, result
```

### Step 4: 执行参数调优循环

```python
def param_tuning_loop(config, param_space, strategy, budget):
    # 初始化试验记录
    trials = []
    best_metric = float('inf')
    best_params = None
    
    # 生成试验列表
    if strategy == 'grid':
        trial_list = grid_search(param_space, budget)
    elif strategy == 'random':
        trial_list = random_search(param_space, budget)
    elif strategy == 'bayesian':
        # 贝叶斯优化动态生成
        trial_list = []
    
    # 执行试验
    for i, params in enumerate(trial_list):
        print(f"\n{'='*60}")
        print(f"试验 {i+1}/{budget}")
        print(f"参数: {params}")
        print(f"{'='*60}")
        
        # Step 4.1: 修改参数配置文件
        apply_params(config['param_config_file'], params)
        
        # Step 4.2: 重新运行（跳过构建）
        run_result = run_slam_system(config)
        
        # Step 4.3: 评估性能
        eval_result = evaluate_trajectory(config, run_result['trajectory'])
        
        # Step 4.4: 记录结果
        trial = {
            'id': i + 1,
            'params': params,
            'metrics': eval_result['metrics'],
            'target_metric': eval_result['target_value'],
            'duration_sec': run_result['duration'],
            'timestamp': datetime.now().isoformat()
        }
        trials.append(trial)
        
        # Step 4.5: 更新最优
        if eval_result['target_value'] < best_metric:
            best_metric = eval_result['target_value']
            best_params = params.copy()
            print(f"✓ 新最优！{config['target_metric']}: {best_metric:.4f}")
        
        # Step 4.6: 保存试验记录
        save_trial(trial, config['session_dir'])
    
    return trials, best_params, best_metric
```

### Step 5: 应用参数到配置文件

```python
def apply_params(config_file, params):
    """
    将参数应用到配置文件
    支持 YAML, JSON 格式
    """
    if config_file.endswith('.yaml') or config_file.endswith('.yml'):
        import yaml
        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)
        
        # 更新参数
        for key, value in params.items():
            # 支持嵌套键（如 "tracker.max_features"）
            keys = key.split('.')
            d = config
            for k in keys[:-1]:
                d = d.setdefault(k, {})
            d[keys[-1]] = value
        
        with open(config_file, 'w') as f:
            yaml.dump(config, f, default_flow_style=False)
    
    elif config_file.endswith('.json'):
        import json
        with open(config_file, 'r') as f:
            config = json.load(f)
        
        for key, value in params.items():
            keys = key.split('.')
            d = config
            for k in keys[:-1]:
                d = d.setdefault(k, {})
            d[keys[-1]] = value
        
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
```

### Step 6: 生成调优报告

```python
def generate_tuning_report(trials, best_params, best_metric, config):
    """
    生成参数调优报告
    """
    report = f"""# 参数调优报告

## 调优配置

- **调优策略**: {config['strategy']}
- **评估次数**: {len(trials)}
- **目标指标**: {config['target_metric']}
- **参数空间**:
{format_param_space(config['param_space'])}

## 最优参数

```yaml
{yaml.dump(best_params, default_flow_style=False)}
```

**最优性能**: {best_metric:.4f}

## 调优历史

| 试验 | 参数 | 目标指标 | 时间 |
|------|------|---------|------|
"""
    
    for trial in trials:
        params_str = ', '.join([f"{k}={v}" for k, v in trial['params'].items()])
        report += f"| {trial['id']} | {params_str} | {trial['target_metric']:.4f} | {trial['duration_sec']}s |\n"
    
    # 添加优化曲线分析
    report += f"""

## 优化曲线

- **初始性能**: {trials[0]['target_metric']:.4f}
- **最终性能**: {trials[-1]['target_metric']:.4f}
- **最优性能**: {best_metric:.4f}
- **提升**: {(trials[0]['target_metric'] - best_metric) / trials[0]['target_metric'] * 100:.1f}%

## 参数灵敏度分析

"""
    
    # 分析每个参数的影响
    for param_name in config['param_space'].keys():
        param_values = [t['params'][param_name] for t in trials]
        param_metrics = [t['target_metric'] for t in trials]
        
        # 计算相关系数
        correlation = np.corrcoef(param_values, param_metrics)[0, 1]
        
        report += f"- **{param_name}**: 相关系数 = {correlation:.3f}"
        if abs(correlation) > 0.7:
            report += f" (高影响)"
        elif abs(correlation) > 0.3:
            report += f" (中等影响)"
        else:
            report += f" (低影响)"
        report += "\n"
    
    return report
```

### Step 7: 输出调优结果

```markdown
✅ 参数调优完成

📊 调优统计:
- 策略: bayesian
- 评估次数: 50
- 最优性能: 0.0823 (提升 67.1%)

🎯 最优参数:
  max_features: 320
  min_inliers: 15
  ...

📈 优化曲线:
  初始: 0.2500
  最终: 0.0823
  提升: 67.1%

🔍 参数灵敏度:
  - max_features: 相关系数 0.82 (高影响)
  - min_inliers: 相关系数 0.45 (中等影响)

📁 详细结果:
  - 调优配置: {session_dir}/param-tuning/param-tuning-config.json
  - 试验记录: {session_dir}/param-tuning/trials.json
  - 最优参数: {session_dir}/param-tuning/best-params.json
  - 调优报告: {session_dir}/param-tuning/tuning-report.md

是否应用最优参数到配置文件？(Y/n)
```

## 错误处理

### 错误 1: 参数配置文件不存在

```
❌ 参数配置文件不存在

路径: {config_file}

解决方案:
1. 检查 project-spec.md 中的参数配置
2. 运行 slam-project-profiler 重新收集参数信息
3. 手动创建参数配置文件
```

### 错误 2: 参数超出范围

```
❌ 参数超出范围

参数: max_features = 1000
范围: [100, 500]

解决方案:
1. 检查参数范围定义
2. 调整参数搜索空间
3. 添加参数约束
```

### 错误 3: 评估失败

```
❌ 评估失败

试验 {trial_id} 评估失败:
{error_message}

解决方案:
1. 检查运行日志
2. 跳过该试验，继续下一轮
3. 调整参数范围，避免无效区域
```

## 注意事项

1. **参数独立性**：确保参数之间没有强耦合，否则搜索效率低
2. **评估成本**：每次评估可能耗时较长，选择高效的搜索策略
3. **参数范围**：范围过大会降低搜索效率，过小可能错过最优解
4. **随机种子**：使用固定随机种子，保证结果可复现
5. **备份配置**：调优前备份原始配置文件，便于回退
6. **收敛判断**：如果连续 N 次评估没有改进，提前终止
