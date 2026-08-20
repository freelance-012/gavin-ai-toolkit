# SLAM 优化理论基础

> 本文档介绍 SLAM 后端优化中的关键理论知识，帮助理解优化质量如何影响最终精度，以及如何诊断和优化问题。

---

## 目录

1. [优化问题概述](#1-优化问题概述)
2. [Hessian 矩阵分析](#2-hessian-矩阵分析)
3. [雅可比矩阵质量](#3-雅可比矩阵质量)
4. [残差分布分析](#4-残差分布分析)
5. [权重分布诊断](#5-权重分布诊断)
6. [实战应用](#6-实战应用)

---

## 1. 优化问题概述

### 1.1 SLAM 后端优化的数学形式

SLAM 后端优化通常建模为非线性最小二乘问题：

$$
\mathbf{x}^* = \arg\min_{\mathbf{x}} \frac{1}{2} \sum_{k=1}^{m} \|\mathbf{r}_k(\mathbf{x})\|_{\Sigma_k^{-1}}^2
$$

其中：
- $\mathbf{x}$：优化变量（位姿、速度、bias、 landmark 等）
- $\mathbf{r}_k(\mathbf{x})$：第 $k$ 个残差
- $\Sigma_k$：第 $k$ 个残差的协方差矩阵
- $\|\mathbf{r}\|_{\Sigma^{-1}}^2 = \mathbf{r}^T \Sigma^{-1} \mathbf{r}$：马氏距离

### 1.2 高斯-牛顿法

定义目标函数：

$$
F(\mathbf{x}) = \frac{1}{2} \sum_{k=1}^{m} \mathbf{r}_k(\mathbf{x})^T \Sigma_k^{-1} \mathbf{r}_k(\mathbf{x})
$$

对 $\mathbf{r}_k(\mathbf{x})$ 在当前估计 $\mathbf{x}_0$ 处进行一阶泰勒展开：

$$
\mathbf{r}_k(\mathbf{x}_0 + \Delta\mathbf{x}) \approx \mathbf{r}_k(\mathbf{x}_0) + \mathbf{J}_k \Delta\mathbf{x}
$$

其中 $\mathbf{J}_k = \frac{\partial \mathbf{r}_k}{\partial \mathbf{x}}$ 是雅可比矩阵。

代入目标函数：

$$
F(\mathbf{x}_0 + \Delta\mathbf{x}) \approx \frac{1}{2} \sum_{k=1}^{m} \|\mathbf{r}_k + \mathbf{J}_k \Delta\mathbf{x}\|_{\Sigma_k^{-1}}^2
$$

展开并整理：

$$
F(\mathbf{x}_0 + \Delta\mathbf{x}) \approx F(\mathbf{x}_0) + \mathbf{b}^T \Delta\mathbf{x} + \frac{1}{2} \Delta\mathbf{x}^T \mathbf{H} \Delta\mathbf{x}
$$

其中：
- **Hessian 矩阵**：$\mathbf{H} = \sum_{k=1}^{m} \mathbf{J}_k^T \Sigma_k^{-1} \mathbf{J}_k$
- **梯度向量**：$\mathbf{b} = \sum_{k=1}^{m} \mathbf{J}_k^T \Sigma_k^{-1} \mathbf{r}_k$

令梯度为零，得到线性系统：

$$
\mathbf{H} \Delta\mathbf{x} = -\mathbf{b}
$$

### 1.3 Levenberg-Marquardt 方法

为解决 Hessian 矩阵病态问题，引入阻尼因子 $\lambda$：

$$
(\mathbf{H} + \lambda \text{diag}(\mathbf{H})) \Delta\mathbf{x} = -\mathbf{b}
$$

- $\lambda$ 小：接近高斯-牛顿法（快速但可能不稳定）
- $\lambda$ 大：接近梯度下降法（稳定但收敛慢）

---

## 2. Hessian 矩阵分析

### 2.1 Hessian 矩阵的物理意义

Hessian 矩阵 $\mathbf{H}$ 反映了优化问题的**曲率信息**：

- **对角线元素** $H_{ii}$：第 $i$ 个变量的自信息量（约束强度）
- **非对角线元素** $H_{ij}$：变量 $i$ 和 $j$ 之间的耦合程度
- **特征值**：各个方向上的曲率（约束强度）

### 2.2 条件数分析

**条件数**定义为最大特征值与最小特征值的比值：

$$
\kappa(\mathbf{H}) = \frac{\lambda_{\max}}{\lambda_{\min}}
$$

#### 条件数的物理意义

| 条件数范围 | 优化质量 | 精度影响 | 典型原因 |
|-----------|---------|---------|---------|
| $\kappa < 10^2$ | 优秀 | 高精度 | 良好约束、合理参数化 |
| $10^2 \leq \kappa < 10^4$ | 良好 | 中等精度 | 部分弱约束 |
| $10^4 \leq \kappa < 10^6$ | 较差 | 精度下降 | 病态问题、冗余参数 |
| $\kappa \geq 10^6$ | 病态 | 严重退化 | 严重病态、数值不稳定 |

#### 条件数与精度的理论关系

对于线性系统 $\mathbf{H} \Delta\mathbf{x} = -\mathbf{b}$，如果 $\mathbf{b}$ 有误差 $\delta\mathbf{b}$，则解的误差：

$$
\frac{\|\delta\Delta\mathbf{x}\|}{\|\Delta\mathbf{x}\|} \leq \kappa(\mathbf{H}) \frac{\|\delta\mathbf{b}\|}{\|\mathbf{b}\|}
$$

**结论**：条件数越大，对误差越敏感，精度越差。

### 2.3 特征值分析

对 Hessian 矩阵进行特征分解：

$$
\mathbf{H} = \mathbf{Q} \mathbf{\Lambda} \mathbf{Q}^T
$$

其中 $\mathbf{\Lambda} = \text{diag}(\lambda_1, \lambda_2, \ldots, \lambda_n)$，$\lambda_1 \geq \lambda_2 \geq \ldots \geq \lambda_n$。

#### 特征值的物理意义

- **大特征值**：强约束方向，估计精度高
- **小特征值**：弱约束方向，估计精度低
- **零特征值**：无约束方向（规范自由度或冗余参数）

#### 特征值分布诊断

```python
import numpy as np

def analyze_hessian(H):
    """分析 Hessian 矩阵"""
    eigenvalues = np.linalg.eigvalsh(H)
    
    # 条件数
    condition_number = eigenvalues[-1] / eigenvalues[0]
    
    # 特征值分布
    print(f"条件数: {condition_number:.2e}")
    print(f"最大特征值: {eigenvalues[-1]:.2e}")
    print(f"最小特征值: {eigenvalues[0]:.2e}")
    print(f"零特征值数量: {np.sum(eigenvalues < 1e-10)}")
    
    # 识别弱约束方向
    weak_directions = np.where(eigenvalues < 1e-6)[0]
    if len(weak_directions) > 0:
        print(f"弱约束方向数量: {len(weak_directions)}")
        print(f"对应的特征向量（需要检查的参数）:")
        eigenvectors = np.linalg.eigh(H)[1]
        for idx in weak_directions:
            print(f"  特征值 {eigenvalues[idx]:.2e}: {eigenvectors[:, idx]}")
    
    return condition_number, eigenvalues
```

### 2.4 病态问题的常见原因

#### 1. 冗余参数（规范自由度）

**问题**：存在无约束的方向（零特征值）

**例子**：
- 单目 VIO 的尺度未约束
- 纯视觉 SLAM 的绝对位置和朝向未约束
- 边缘化后引入的先验不完整

**解决**：
- 添加先验约束（如固定第一帧位姿）
- 使用合适的参数化（如误差状态）
- 检查边缘化是否正确

#### 2. 弱约束

**问题**：某些参数只有很弱的约束（小特征值）

**例子**：
- 远距离 landmark 的深度
- 快速运动时的 IMU bias
- 退化运动（如纯旋转）

**解决**：
- 边缘化弱约束参数
- 增加观测（更多特征、更多帧）
- 改进运动激励

#### 3. 参数化问题

**问题**：参数化方式导致 Hessian 病态

**例子**：
- 使用欧拉角（奇异性）
- 使用过大的参数（数值不稳定）
- 参数尺度差异大

**解决**：
- 使用李群/李代数（SO(3), SE(3)）
- 参数归一化
- 使用误差状态

#### 4. 数值误差累积

**问题**：浮点运算误差导致 Hessian 不对称或不正定

**解决**：
- 使用双精度浮点数
- 定期重新计算 Hessian
- 使用稳定的 Cholesky 分解

### 2.5 改进策略

#### 1. 正则化（Levenberg-Marquardt）

$$
(\mathbf{H} + \lambda \text{diag}(\mathbf{H})) \Delta\mathbf{x} = -\mathbf{b}
$$

- 增加对角线元素，改善条件数
- $\lambda$ 自适应调整

#### 2. 降维（边缘化）

边缘化弱约束参数，减少优化变量：

$$
\mathbf{H}_{mm} = \mathbf{H}_{aa} - \mathbf{H}_{ab} \mathbf{H}_{bb}^{-1} \mathbf{H}_{ba}
$$

#### 3. 预条件

使用预条件矩阵 $\mathbf{M}$ 改善条件数：

$$
\mathbf{M}^{-1} \mathbf{H} \Delta\mathbf{x} = -\mathbf{M}^{-1} \mathbf{b}
$$

常用预条件：
- 雅可比预条件：$\mathbf{M} = \text{diag}(\mathbf{H})$
- 不完全 Cholesky 分解

#### 4. 重新参数化

改进参数化方式：
- 使用李群/李代数
- 使用误差状态
- 参数归一化

---

## 3. 雅可比矩阵质量

### 3.1 雅可比矩阵的作用

雅可比矩阵 $\mathbf{J}_k = \frac{\partial \mathbf{r}_k}{\partial \mathbf{x}}$ 是残差对优化变量的导数，反映：

- **线性化质量**：一阶近似的准确性
- **约束强度**：残差对参数的敏感程度
- **信息量**：观测包含的信息量

### 3.2 线性化误差

#### 理论分析

在 $\mathbf{x}_0$ 处线性化：

$$
\mathbf{r}(\mathbf{x}_0 + \Delta\mathbf{x}) \approx \mathbf{r}(\mathbf{x}_0) + \mathbf{J} \Delta\mathbf{x}
$$

线性化误差（二阶项）：

$$
\mathbf{e}_{\text{lin}} = \frac{1}{2} \Delta\mathbf{x}^T \mathbf{H}_r \Delta\mathbf{x}
$$

其中 $\mathbf{H}_r = \frac{\partial^2 \mathbf{r}}{\partial \mathbf{x}^2}$ 是残差的二阶导数。

#### 线性化质量的条件

线性化有效的条件：

$$
\|\mathbf{e}_{\text{lin}}\| \ll \|\mathbf{r}\|
$$

即：

$$
\frac{1}{2} \|\Delta\mathbf{x}^T \mathbf{H}_r \Delta\mathbf{x}\| \ll \|\mathbf{r}\|
$$

**结论**：
- $\Delta\mathbf{x}$ 小：线性化质量好
- $\mathbf{H}_r$ 小：残差接近线性，线性化质量好
- $\|\mathbf{r}\|$ 大：对线性化误差不敏感

### 3.3 雅可比矩阵的计算方法

#### 1. 解析推导（推荐）

**优点**：
- 精确，无截断误差
- 计算效率高
- 数值稳定

**缺点**：
- 推导复杂，容易出错
- 需要数学功底

**例子**：视觉重投影误差的雅可比

$$
\mathbf{r}_V = \mathbf{z}_{obs} - \pi(\mathbf{T}_{cb}^{-1} \mathbf{T}_{bw}^{-1} \mathbf{p}_w^f)
$$

对位姿 $\mathbf{T}_{bw}$ 的雅可比需要链式法则：

$$
\frac{\partial \mathbf{r}_V}{\partial \mathbf{T}_{bw}} = -\frac{\partial \pi}{\partial \mathbf{p}_c} \frac{\partial \mathbf{p}_c}{\partial \mathbf{T}_{bw}}
$$

#### 2. 数值差分

**前向差分**：

$$
\mathbf{J}_{ij} \approx \frac{r_i(\mathbf{x} + h\mathbf{e}_j) - r_i(\mathbf{x})}{h}
$$

**中心差分**（更精确）：

$$
\mathbf{J}_{ij} \approx \frac{r_i(\mathbf{x} + h\mathbf{e}_j) - r_i(\mathbf{x} - h\mathbf{e}_j)}{2h}
$$

**优点**：
- 实现简单，不易出错
- 适用于任意函数

**缺点**：
- 计算效率低（需要 $n+1$ 次函数求值）
- 截断误差（$h$ 的选择）
- 数值不稳定（$h$ 太小导致舍入误差）

**步长选择**：

$$
h = \sqrt{\epsilon_{\text{machine}}} \|\mathbf{x}\|
$$

其中 $\epsilon_{\text{machine}} \approx 10^{-16}$（双精度）。

#### 3. 自动微分

使用 Ceres Solver、Jet 库等自动微分工具。

**优点**：
- 精确（机器精度）
- 实现简单
- 计算效率高

**缺点**：
- 需要特定的框架
- 对复杂运算支持有限

### 3.4 雅可比矩阵的质量诊断

#### 1. 检查雅可比矩阵的范数

```cpp
// 检查雅可比矩阵的 Frobenius 范数
double J_norm = J.norm();
if (J_norm < 1e-10) {
    LOG(WARNING) << "雅可比矩阵接近零，约束很弱";
}
if (J_norm > 1e10) {
    LOG(WARNING) << "雅可比矩阵过大，可能数值不稳定";
}
```

#### 2. 检查雅可比矩阵的条件数

```cpp
// 计算 J^T J 的条件数
Eigen::MatrixXd H = J.transpose() * J;
Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> eig(H);
double condition_number = eig.eigenvalues().maxCoeff() / eig.eigenvalues().minCoeff();

if (condition_number > 1e6) {
    LOG(WARNING) << "雅可比矩阵病态，条件数: " << condition_number;
}
```

#### 3. 检查线性化点的有效性

```cpp
// 检查更新步长
double update_norm = delta_x.norm();
if (update_norm > 0.1) {  // 阈值根据具体问题调整
    LOG(WARNING) << "更新步长过大，线性化可能不准确: " << update_norm;
}
```

### 3.5 改进策略

#### 1. 使用解析雅可比

**优先选择**：精度最高，效率最好

#### 2. 改进线性化点

- 使用 FEJ (First Estimate Jacobian)：边缘化时使用首次估计的雅可比
- 使用迭代线性化：多次线性化，逐步改进

#### 3. 正则化

对于病态雅可比矩阵：

$$
\mathbf{J}_{\text{reg}} = \mathbf{J} + \lambda \mathbf{I}
$$

#### 4. 降维

边缘化弱约束参数，减少雅可比矩阵的列数。

---

## 4. 残差分布分析

### 4.1 残差的统计特性

#### 理想情况

如果模型正确、噪声高斯分布，残差应该满足：

$$
\mathbf{r}_k \sim \mathcal{N}(\mathbf{0}, \Sigma_k)
$$

即：
- 均值为零：$E[\mathbf{r}_k] = \mathbf{0}$
- 协方差为 $\Sigma_k$：$E[\mathbf{r}_k \mathbf{r}_k^T] = \Sigma_k$
- 归一化残差：$\mathbf{r}_k^T \Sigma_k^{-1} \mathbf{r}_k \sim \chi^2(d)$，其中 $d$ 是残差维度

#### 归一化残差检验

定义归一化残差平方（NIS, Normalized Innovation Squared）：

$$
\text{NIS}_k = \mathbf{r}_k^T \Sigma_k^{-1} \mathbf{r}_k
$$

理论上 $\text{NIS}_k \sim \chi^2(d)$，其中 $d$ 是残差维度。

#### 卡方检验

对于 $d$ 维残差，在 95% 置信水平下：

$$
\text{NIS}_k \in [\chi^2_{d, 0.025}, \chi^2_{d, 0.975}]
$$

常用值：
- $d = 2$（2D 视觉残差）：$[0.0506, 7.378]$
- $d = 3$（3D 残差）：$[0.216, 9.348]$
- $d = 15$（IMU 残差）：$[6.262, 27.488]$

### 4.2 残差分布异常的类型

#### 1. 均值非零

**症状**：$E[\mathbf{r}_k] \neq \mathbf{0}$

**原因**：
- 系统误差（外参标定错误、时间同步偏差）
- 模型错误（运动模型、观测模型不正确）
- 未建模的动态物体

**诊断**：

```python
import numpy as np
from scipy import stats

def check_residual_mean(residuals, expected_mean=0):
    """检查残差均值是否为零"""
    mean = np.mean(residuals, axis=0)
    
    # t 检验
    t_stat, p_value = stats.ttest_1samp(residuals, expected_mean, axis=0)
    
    print(f"残差均值: {mean}")
    print(f"p 值: {p_value}")
    
    if np.any(p_value < 0.05):
        print("警告: 残差均值显著非零，可能存在系统误差")
    
    return mean, p_value
```

#### 2. 协方差不匹配

**症状**：$E[\mathbf{r}_k \mathbf{r}_k^T] \neq \Sigma_k$

**原因**：
- 噪声参数设置错误（过大或过小）
- 存在未建模的噪声源
- 外点比例过高

**诊断**：

```python
def check_residual_covariance(residuals, expected_cov):
    """检查残差协方差是否匹配"""
    actual_cov = np.cov(residuals, rowvar=False)
    
    # 比较对角线元素（方差）
    variance_ratio = np.diag(actual_cov) / np.diag(expected_cov)
    
    print(f"方差比值: {variance_ratio}")
    
    if np.any(variance_ratio > 2.0) or np.any(variance_ratio < 0.5):
        print("警告: 残差协方差与预期不匹配")
    
    return actual_cov, variance_ratio
```

#### 3. 非高斯分布

**症状**：残差分布有重尾、偏斜等

**原因**：
- 外点（错误匹配、动态物体）
- 噪声非高斯（脉冲噪声、量化误差）
- 模型错误

**诊断**：

```python
def check_gaussianity(residuals):
    """检查残差是否服从高斯分布"""
    from scipy import stats
    
    # Shapiro-Wilk 检验
    stat, p_value = stats.shapiro(residuals.flatten())
    
    print(f"Shapiro-Wilk 检验 p 值: {p_value}")
    
    if p_value < 0.05:
        print("警告: 残差不服从高斯分布")
        
        # 检查偏度和峰度
        skewness = stats.skew(residuals.flatten())
        kurtosis = stats.kurtosis(residuals.flatten())
        
        print(f"偏度: {skewness} (高斯分布: 0)")
        print(f"峰度: {kurtosis} (高斯分布: 0)")
        
        if abs(skewness) > 1:
            print("  - 分布有明显偏斜")
        if kurtosis > 3:
            print("  - 分布有重尾（可能存在外点）")
    
    return p_value
```

#### 4. 存在外点

**症状**：部分残差远大于预期

**原因**：
- 错误匹配
- 动态物体
- 传感器故障

**诊断**：

```python
def detect_outliers(residuals, threshold=3.0):
    """检测外点"""
    # 计算马氏距离
    mean = np.mean(residuals, axis=0)
    cov = np.cov(residuals, rowvar=False)
    
    try:
        mahal_dist = np.sqrt(
            np.sum(
                (residuals - mean) @ np.linalg.inv(cov) * (residuals - mean),
                axis=1
            )
        )
    except np.linalg.LinAlgError:
        # 协方差矩阵奇异，使用欧氏距离
        mahal_dist = np.linalg.norm(residuals - mean, axis=1)
    
    # 检测外点
    outliers = mahal_dist > threshold
    
    print(f"检测到 {np.sum(outliers)} 个外点 ({100*np.mean(outliers):.1f}%)")
    
    return outliers, mahal_dist
```

### 4.3 鲁棒核函数

当存在外点时，使用鲁棒核函数 $\rho(\cdot)$ 替代平方损失：

$$
F(\mathbf{x}) = \sum_{k=1}^{m} \rho(\|\mathbf{r}_k\|_{\Sigma_k^{-1}}^2)
$$

#### 常用核函数

| 核函数 | 公式 | 特点 |
|--------|------|------|
| **L2 (平方)** | $\rho(s) = s$ | 标准最小二乘，对外点敏感 |
| **Huber** | $\rho(s) = \begin{cases} s & s \leq \delta \\ 2\delta\sqrt{s} - \delta^2 & s > \delta \end{cases}$ | 平滑过渡，常用 |
| **Cauchy** | $\rho(s) = \delta^2 \log(1 + s/\delta^2)$ | 强鲁棒性 |
| **Tukey** | $\rho(s) = \begin{cases} \frac{\delta^2}{6}(1 - (1 - s/\delta^2)^3) & s \leq \delta \\ \frac{\delta^2}{6} & s > \delta \end{cases}$ | 完全忽略外点 |

其中 $\delta$ 是核函数参数，通常取 $1.345\sigma$（Huber）或 $4.685\sigma$（Tukey），$\sigma$ 是残差标准差。

#### 核函数的选择

```cpp
// Ceres Solver 中的核函数选择
ceres::Problem problem;

// Huber 核函数（推荐）
ceres::HuberLoss* huber_loss = new ceres::HuberLoss(1.345 * residual_std);
problem.AddCostFunction(cost_function, huber_loss);

// Cauchy 核函数（强鲁棒性）
ceres::CauchyLoss* cauchy_loss = new ceres::CauchyLoss(4.685 * residual_std);
problem.AddCostFunction(cost_function, cauchy_loss);
```

### 4.4 迭代重加权 (IRWLS)

当噪声方差未知或存在异方差时，使用迭代重加权：

**算法流程**：

1. 初始化权重 $w_k^{(0)} = 1$
2. 求解加权最小二乘：
   $$
   \mathbf{x}^{(i+1)} = \arg\min_{\mathbf{x}} \sum_{k=1}^{m} w_k^{(i)} \|\mathbf{r}_k(\mathbf{x})\|_{\Sigma_k^{-1}}^2
   $$
3. 更新权重：
   $$
   w_k^{(i+1)} = \frac{\rho'(\|\mathbf{r}_k(\mathbf{x}^{(i+1)})\|)}{\|\mathbf{r}_k(\mathbf{x}^{(i+1)})\|}
   $$
4. 重复步骤 2-3 直到收敛

---

## 5. 权重分布诊断

### 5.1 权重的物理意义

权重矩阵 $\mathbf{W}_k = \Sigma_k^{-1}$ 是信息矩阵，反映：

- **对角线元素** $W_{ii}$：第 $i$ 个观测维度的信息量
- **非对角线元素** $W_{ij}$：不同维度之间的相关性
- **特征值**：各个方向上的信息量

### 5.2 权重异常的类型

#### 1. 权重过大

**症状**：$W_{ii} \gg 1$（或 $\Sigma_{ii} \ll 1$）

**原因**：
- 对传感器精度过于乐观
- 未考虑系统误差
- 外点被赋予过高权重

**影响**：
- 优化过度拟合该观测
- 其他观测被忽略
- 估计偏差

**诊断**：

```python
def check_weight_magnitude(weights, threshold=1e6):
    """检查权重是否过大"""
    max_weight = np.max(np.abs(weights))
    
    print(f"最大权重: {max_weight:.2e}")
    
    if max_weight > threshold:
        print("警告: 权重过大，可能对传感器精度过于乐观")
    
    return max_weight > threshold
```

#### 2. 权重过小

**症状**：$W_{ii} \ll 1$（或 $\Sigma_{ii} \gg 1$）

**原因**：
- 对传感器精度过于保守
- 未充分利用观测信息
- 数值不稳定

**影响**：
- 观测信息未被充分利用
- 估计精度下降
- 收敛速度慢

**诊断**：

```python
def check_small_weights(weights, threshold=1e-6):
    """检查权重是否过小"""
    min_weight = np.min(np.abs(weights))
    
    print(f"最小权重: {min_weight:.2e}")
    
    if min_weight < threshold:
        print("警告: 权重过小，观测信息未被充分利用")
    
    return min_weight < threshold
```

#### 3. 权重分布不均

**症状**：不同观测的权重差异很大

**原因**：
- 不同传感器的精度差异大
- 不同距离的 landmark 精度差异大
- 未进行权重归一化

**影响**：
- 高精度观测主导优化
- 低精度观测被忽略
- 估计偏差

**诊断**：

```python
def check_weight_distribution(weights):
    """检查权重分布是否均匀"""
    weights_flat = weights.flatten()
    
    # 计算权重的变异系数
    mean_weight = np.mean(weights_flat)
    std_weight = np.std(weights_flat)
    cv = std_weight / mean_weight
    
    print(f"权重变异系数: {cv:.2f}")
    
    if cv > 1.0:
        print("警告: 权重分布不均，可能导致估计偏差")
        
        # 分析权重分布
        percentiles = np.percentile(weights_flat, [25, 50, 75, 95])
        print(f"权重分位数: 25%={percentiles[0]:.2e}, 50%={percentiles[1]:.2e}, "
              f"75%={percentiles[2]:.2e}, 95%={percentiles[3]:.2e}")
    
    return cv > 1.0
```

#### 4. 权重矩阵非正定

**症状**：$\mathbf{W}_k$ 有负特征值或零特征值

**原因**：
- 协方差矩阵估计错误
- 数值误差累积
- 观测维度之间存在线性相关性

**影响**：
- 优化问题病态
- 求解失败
- 估计不稳定

**诊断**：

```python
def check_weight_positive_definite(weights):
    """检查权重矩阵是否正定"""
    eigenvalues = np.linalg.eigvalsh(weights)
    
    print(f"最小特征值: {np.min(eigenvalues):.2e}")
    
    if np.any(eigenvalues <= 0):
        print("错误: 权重矩阵非正定")
        print(f"负特征值数量: {np.sum(eigenvalues < 0)}")
        print(f"零特征值数量: {np.sum(eigenvalues < 1e-10)}")
        return False
    
    return True
```

### 5.3 权重调整策略

#### 1. 基于残差的自适应权重

根据残差大小动态调整权重：

$$
w_k = \frac{1}{1 + (\|\mathbf{r}_k\| / \delta)^2}
$$

```cpp
// 自适应权重计算
double residual_norm = r.norm();
double delta = 1.345 * expected_std;  // Huber 参数
double weight = 1.0 / (1.0 + std::pow(residual_norm / delta, 2));

// 应用到信息矩阵
Eigen::MatrixXd weighted_info = weight * info_matrix;
```

#### 2. 基于距离的权重

对于视觉 landmark，距离越远精度越低：

$$
w_k = \frac{1}{d_k^2}
$$

其中 $d_k$ 是 landmark 深度。

```cpp
// 基于深度的权重
double depth = landmark.depth();
double weight = 1.0 / (depth * depth);

// 限制权重范围
weight = std::clamp(weight, min_weight, max_weight);
```

#### 3. 基于特征质量的权重

根据特征跟踪质量调整权重：

$$
w_k = \frac{\text{response}_k}{\sum_j \text{response}_j}
$$

```cpp
// 基于特征响应值的权重
double response = feature.response();
double total_response = sum_of_all_responses;
double weight = response / total_response;
```

#### 4. 权重归一化

确保权重在合理范围内：

```cpp
// 权重归一化
double max_weight = weights.maxCoeff();
double min_weight = weights.minCoeff();

// 归一化到 [1, 100]
weights = (weights - min_weight) / (max_weight - min_weight) * 99 + 1;
```

---

## 6. 实战应用

### 6.1 从日志中诊断优化问题

#### 诊断流程

```
1. 检查收敛性
   ├─ 是否达到最大迭代次数？
   ├─ 代价函数是否下降？
   └─ 更新步长是否足够小？

2. 分析 Hessian 矩阵
   ├─ 条件数是否过大？
   ├─ 是否有零特征值？
   └─ 特征值分布是否合理？

3. 分析雅可比矩阵
   ├─ 是否使用解析雅可比？
   ├─ 雅可比范数是否合理？
   └─ 线性化点是否有效？

4. 分析残差分布
   ├─ 均值是否为零？
   ├─ 协方差是否匹配？
   ├─ 是否存在外点？
   └─ 是否需要鲁棒核函数？

5. 分析权重分布
   ├─ 权重是否过大/过小？
   ├─ 权重分布是否均匀？
   └─ 是否需要自适应权重？
```

#### 日志分析代码示例

```python
import numpy as np
import json

class OptimizationDiagnostics:
    """优化问题诊断工具"""
    
    def __init__(self, log_file):
        with open(log_file, 'r') as f:
            self.log_data = json.load(f)
    
    def diagnose(self):
        """运行完整诊断"""
        print("=" * 60)
        print("优化问题诊断报告")
        print("=" * 60)
        
        self.check_convergence()
        self.analyze_hessian()
        self.analyze_residuals()
        self.analyze_weights()
        
        print("=" * 60)
    
    def check_convergence(self):
        """检查收敛性"""
        print("\n[1] 收敛性检查")
        
        iterations = self.log_data.get('iterations', [])
        if not iterations:
            print("  ✗ 无迭代数据")
            return
        
        final_iter = iterations[-1]
        
        # 检查迭代次数
        max_iter = self.log_data.get('max_iterations', 10)
        if len(iterations) >= max_iter:
            print(f"  ⚠ 达到最大迭代次数 ({max_iter})")
        
        # 检查代价函数
        costs = [it['cost'] for it in iterations]
        if costs[-1] > costs[0]:
            print(f"  ✗ 代价函数未下降: {costs[0]:.4e} → {costs[-1]:.4e}")
        else:
            improvement = (costs[0] - costs[-1]) / costs[0] * 100
            print(f"  ✓ 代价函数下降 {improvement:.2f}%")
        
        # 检查更新步长
        update_norms = [it.get('update_norm', 0) for it in iterations]
        if update_norms[-1] > 0.1:
            print(f"  ⚠ 最终更新步长较大: {update_norms[-1]:.4e}")
        else:
            print(f"  ✓ 更新步长合理: {update_norms[-1]:.4e}")
    
    def analyze_hessian(self):
        """分析 Hessian 矩阵"""
        print("\n[2] Hessian 矩阵分析")
        
        hessian = self.log_data.get('hessian')
        if hessian is None:
            print("  ⚠ 无 Hessian 矩阵数据")
            return
        
        H = np.array(hessian)
        
        # 计算特征值
        eigenvalues = np.linalg.eigvalsh(H)
        condition_number = eigenvalues[-1] / eigenvalues[0]
        
        print(f"  条件数: {condition_number:.2e}")
        
        if condition_number > 1e6:
            print(f"  ✗ 条件数过大，问题病态")
        elif condition_number > 1e4:
            print(f"  ⚠ 条件数较大，可能影响精度")
        else:
            print(f"  ✓ 条件数良好")
        
        # 检查零特征值
        zero_eigenvalues = np.sum(eigenvalues < 1e-10)
        if zero_eigenvalues > 0:
            print(f"  ✗ 存在 {zero_eigenvalues} 个零特征值（冗余参数）")
        
        # 检查弱约束
        weak_constraints = np.sum(eigenvalues < 1e-6)
        if weak_constraints > 0:
            print(f"  ⚠ 存在 {weak_constraints} 个弱约束")
    
    def analyze_residuals(self):
        """分析残差分布"""
        print("\n[3] 残差分布分析")
        
        residuals = self.log_data.get('residuals')
        if residuals is None:
            print("  ⚠ 无残差数据")
            return
        
        residuals = np.array(residuals)
        
        # 检查均值
        mean = np.mean(residuals, axis=0)
        print(f"  残差均值: {np.linalg.norm(mean):.4e}")
        
        if np.linalg.norm(mean) > 0.01:
            print(f"  ⚠ 残差均值非零，可能存在系统误差")
        else:
            print(f"  ✓ 残差均值接近零")
        
        # 检查外点
        residual_norms = np.linalg.norm(residuals, axis=1)
        threshold = 3 * np.std(residual_norms)
        outliers = residual_norms > threshold
        
        outlier_ratio = np.mean(outliers)
        print(f"  外点比例: {outlier_ratio*100:.2f}%")
        
        if outlier_ratio > 0.1:
            print(f"  ⚠ 外点比例过高，建议使用鲁棒核函数")
        else:
            print(f"  ✓ 外点比例正常")
    
    def analyze_weights(self):
        """分析权重分布"""
        print("\n[4] 权重分布分析")
        
        weights = self.log_data.get('weights')
        if weights is None:
            print("  ⚠ 无权重数据")
            return
        
        weights = np.array(weights)
        
        # 检查权重范围
        max_weight = np.max(weights)
        min_weight = np.min(weights)
        
        print(f"  权重范围: [{min_weight:.2e}, {max_weight:.2e}]")
        
        if max_weight > 1e6:
            print(f"  ⚠ 最大权重过大")
        if min_weight < 1e-6:
            print(f"  ⚠ 最小权重过小")
        
        # 检查权重分布
        cv = np.std(weights) / np.mean(weights)
        print(f"  权重变异系数: {cv:.2f}")
        
        if cv > 1.0:
            print(f"  ⚠ 权重分布不均")
        else:
            print(f"  ✓ 权重分布合理")


# 使用示例
if __name__ == '__main__':
    diagnostics = OptimizationDiagnostics('optimization_log.json')
    diagnostics.diagnose()
```

### 6.2 常见症状与改进策略

#### 症状 1：优化不收敛

**可能原因**：
1. Hessian 矩阵病态
2. 初始值太差
3. 步长太大
4. 模型错误

**改进策略**：
1. 增加 LM 阻尼因子
2. 改进初始值（使用更好的初始化方法）
3. 减小步长
4. 检查模型正确性

#### 症状 2：精度下降

**可能原因**：
1. 外点比例过高
2. 噪声参数设置错误
3. 权重分配不合理
4. 边缘化引入误差

**改进策略**：
1. 使用鲁棒核函数
2. 调整噪声参数
3. 使用自适应权重
4. 检查边缘化实现

#### 症状 3：实时性差

**可能原因**：
1. 优化变量太多
2. 迭代次数过多
3. Hessian 矩阵求解慢
4. 边缘化不及时

**改进策略**：
1. 边缘化旧状态
2. 减少最大迭代次数
3. 使用稀疏求解器
4. 优化数据结构

### 6.3 与 slam-debug-helper 的集成

在 `slam-debug-helper` 的 Phase 2（根因诊断）中，可以引用本知识库的理论：

```markdown
## Phase 2: 根因诊断

### 步骤 1: 检查 Hessian 矩阵

读取 optimization_log.json 中的 Hessian 矩阵数据，分析：

1. 计算条件数 κ(H)
2. 如果 κ > 10^6，诊断为"病态优化问题"
3. 参考 knowledge/optimization-theory.md 第 2 节

### 步骤 2: 分析残差分布

读取残差数据，分析：

1. 检查残差均值是否为零
2. 检查外点比例
3. 如果外点比例 > 10%，建议使用鲁棒核函数
4. 参考 knowledge/optimization-theory.md 第 4 节

### 步骤 3: 分析权重分布

读取权重数据，分析：

1. 检查权重范围
2. 检查权重分布均匀性
3. 如果权重分布不均，建议使用自适应权重
4. 参考 knowledge/optimization-theory.md 第 5 节
```

---

## 总结

### 关键知识点

1. **Hessian 矩阵**：反映优化问题的曲率，条件数决定精度
2. **雅可比矩阵**：线性化质量影响优化效果，解析推导优于数值差分
3. **残差分布**：应该服从高斯分布，异常分布表明模型或参数问题
4. **权重分布**：应该合理均匀，异常权重导致估计偏差

### 诊断流程

```
优化问题 → 检查收敛性 → 分析 Hessian → 分析残差 → 分析权重 → 改进策略
```

### 改进策略优先级

1. **高优先级**：修复病态问题（正则化、降维）
2. **中优先级**：处理外点（鲁棒核函数）
3. **低优先级**：优化性能（边缘化、稀疏求解）

---

*本文档持续更新，欢迎补充新的理论和实践经验。*
