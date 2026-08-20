# SLAM 滤波理论基础

> 本文档介绍 SLAM 中常用的滤波算法理论，重点介绍 OpenVINS 中使用的 MSCKF（Multi-State Constraint Kalman Filter）及其预测与更新机制。

---

## 目录

1. [卡尔曼滤波基础](#1-卡尔曼滤波基础)
2. [扩展卡尔曼滤波 (EKF)](#2-扩展卡尔曼滤波-ekf)
3. [误差状态卡尔曼滤波](#3-误差状态卡尔曼滤波)
4. [IMU 预积分与预测](#4-imu-预积分与预测)
5. [MSCKF 多状态约束滤波](#5-msckf-多状态约束滤波)
6. [视觉量测更新](#6-视觉量测更新)
7. [状态增广与边缘化](#7-状态增广与边缘化)
8. [滤波 vs 优化](#8-滤波-vs-优化)
9. [实战应用](#9-实战应用)
10. [滤波诊断指标与问题排查](#10-滤波诊断指标与问题排查)

---

## 1. 卡尔曼滤波基础

### 1.1 线性系统模型

**状态空间模型**：

$$
\begin{aligned}
\mathbf{x}_{k} &= \mathbf{F}_{k} \mathbf{x}_{k-1} + \mathbf{B}_{k} \mathbf{u}_{k} + \mathbf{w}_{k} \\
\mathbf{z}_{k} &= \mathbf{H}_{k} \mathbf{x}_{k} + \mathbf{v}_{k}
\end{aligned}
$$

其中：
- $\mathbf{x}_k$：状态向量（$n \times 1$）
- $\mathbf{F}_k$：状态转移矩阵（$n \times n$）
- $\mathbf{B}_k$：控制输入矩阵（$n \times m$）
- $\mathbf{u}_k$：控制输入（$m \times 1$）
- $\mathbf{w}_k \sim \mathcal{N}(\mathbf{0}, \mathbf{Q}_k)$：过程噪声
- $\mathbf{z}_k$：观测向量（$p \times 1$）
- $\mathbf{H}_k$：观测矩阵（$p \times n$）
- $\mathbf{v}_k \sim \mathcal{N}(\mathbf{0}, \mathbf{R}_k)$：观测噪声

### 1.2 卡尔曼滤波算法

#### 预测步骤（Predict）

**状态预测**：
$$
\hat{\mathbf{x}}_{k|k-1} = \mathbf{F}_{k} \hat{\mathbf{x}}_{k-1|k-1} + \mathbf{B}_{k} \mathbf{u}_{k}
$$

**协方差预测**：
$$
\mathbf{P}_{k|k-1} = \mathbf{F}_{k} \mathbf{P}_{k-1|k-1} \mathbf{F}_{k}^T + \mathbf{Q}_{k}
$$

#### 更新步骤（Update）

**卡尔曼增益**：
$$
\mathbf{K}_{k} = \mathbf{P}_{k|k-1} \mathbf{H}_{k}^T (\mathbf{H}_{k} \mathbf{P}_{k|k-1} \mathbf{H}_{k}^T + \mathbf{R}_{k})^{-1}
$$

**状态更新**：
$$
\hat{\mathbf{x}}_{k|k} = \hat{\mathbf{x}}_{k|k-1} + \mathbf{K}_{k} (\mathbf{z}_{k} - \mathbf{H}_{k} \hat{\mathbf{x}}_{k|k-1})
$$

**协方差更新**：
$$
\mathbf{P}_{k|k} = (\mathbf{I} - \mathbf{K}_{k} \mathbf{H}_{k}) \mathbf{P}_{k|k-1}
$$

**新息（Innovation）**：
$$
\tilde{\mathbf{y}}_{k} = \mathbf{z}_{k} - \mathbf{H}_{k} \hat{\mathbf{x}}_{k|k-1}
$$

**新息协方差**：
$$
\mathbf{S}_{k} = \mathbf{H}_{k} \mathbf{P}_{k|k-1} \mathbf{H}_{k}^T + \mathbf{R}_{k}
$$

### 1.3 卡尔曼滤波的几何解释

- **预测**：根据运动模型，状态的不确定性增加（协方差增大）
- **更新**：根据观测信息，状态的不确定性减少（协方差减小）
- **卡尔曼增益**：平衡预测和观测的权重
  - $\mathbf{K} \to 0$：更相信预测（观测噪声大）
  - $\mathbf{K} \to \mathbf{P}\mathbf{H}^T\mathbf{R}^{-1}$：更相信观测（预测噪声大）

### 1.4 卡尔曼滤波的最优性

卡尔曼滤波在以下条件下是最优的：
1. 系统是线性的
2. 噪声是高斯分布的
3. 噪声统计特性已知且准确

违反这些条件时，需要使用扩展卡尔曼滤波（EKF）或无迹卡尔曼滤波（UKF）。

---

## 2. 扩展卡尔曼滤波 (EKF)

### 2.1 非线性系统模型

**状态方程**：
$$
\mathbf{x}_{k} = f(\mathbf{x}_{k-1}, \mathbf{u}_{k}) + \mathbf{w}_{k}
$$

**观测方程**：
$$
\mathbf{z}_{k} = h(\mathbf{x}_{k}) + \mathbf{v}_{k}
$$

### 2.2 EKF 算法

#### 预测步骤

**状态预测**：
$$
\hat{\mathbf{x}}_{k|k-1} = f(\hat{\mathbf{x}}_{k-1|k-1}, \mathbf{u}_{k})
$$

**雅可比矩阵**：
$$
\mathbf{F}_{k} = \left. \frac{\partial f}{\partial \mathbf{x}} \right|_{\hat{\mathbf{x}}_{k-1|k-1}, \mathbf{u}_{k}}
$$

**协方差预测**：
$$
\mathbf{P}_{k|k-1} = \mathbf{F}_{k} \mathbf{P}_{k-1|k-1} \mathbf{F}_{k}^T + \mathbf{Q}_{k}
$$

#### 更新步骤

**雅可比矩阵**：
$$
\mathbf{H}_{k} = \left. \frac{\partial h}{\partial \mathbf{x}} \right|_{\hat{\mathbf{x}}_{k|k-1}}
$$

**卡尔曼增益**：
$$
\mathbf{K}_{k} = \mathbf{P}_{k|k-1} \mathbf{H}_{k}^T (\mathbf{H}_{k} \mathbf{P}_{k|k-1} \mathbf{H}_{k}^T + \mathbf{R}_{k})^{-1}
$$

**状态更新**：
$$
\hat{\mathbf{x}}_{k|k} = \hat{\mathbf{x}}_{k|k-1} + \mathbf{K}_{k} (\mathbf{z}_{k} - h(\hat{\mathbf{x}}_{k|k-1}))
$$

**协方差更新**：
$$
\mathbf{P}_{k|k} = (\mathbf{I} - \mathbf{K}_{k} \mathbf{H}_{k}) \mathbf{P}_{k|k-1}
$$

### 2.3 EKF 的局限性

1. **线性化误差**：在强非线性区域，一阶泰勒展开不准确
2. **雅可比计算**：需要解析推导雅可比矩阵，复杂且易错
3. **一致性**：可能导致估计不一致（协方差过于乐观）

### 2.4 改进方法

1. **迭代 EKF (IEKF)**：在更新时多次线性化
2. **无迹卡尔曼滤波 (UKF)**：使用 sigma 点近似分布
3. **误差状态 EKF**：对误差状态进行滤波（见第 3 节）

---

## 3. 误差状态卡尔曼滤波

### 3.1 动机

对于姿态估计等问题，使用"名义状态 + 误差状态"的表示方法更合适：

- **名义状态** $\bar{\mathbf{x}}$：使用非线性更新（如四元数乘法）
- **误差状态** $\delta\mathbf{x}$：使用线性更新（卡尔曼滤波）

### 3.2 误差状态定义

对于 IMU 状态 $\mathbf{x} = [\mathbf{p}^T, \mathbf{v}^T, \mathbf{R}^T, \mathbf{b}_a^T, \mathbf{b}_g^T]^T$：

**真实状态**：
$$
\mathbf{x} = \bar{\mathbf{x}} \oplus \delta\mathbf{x}
$$

**误差状态**（小量）：
$$
\delta\mathbf{x} = \begin{bmatrix} \delta\mathbf{p} \\ \delta\mathbf{v} \\ \boldsymbol{\theta} \\ \delta\mathbf{b}_a \\ \delta\mathbf{b}_g \end{bmatrix}
$$

其中 $\boldsymbol{\theta}$ 是旋转误差的李代数表示：
$$
\mathbf{R} = \bar{\mathbf{R}} \exp(\boldsymbol{\theta}^\wedge) \approx \bar{\mathbf{R}} (\mathbf{I} + [\boldsymbol{\theta}]_\times)
$$

### 3.3 误差状态 EKF 算法

#### 预测步骤

**名义状态预测**（非线性）：
$$
\begin{aligned}
\dot{\bar{\mathbf{p}}} &= \bar{\mathbf{v}} \\
\dot{\bar{\mathbf{v}}} &= \bar{\mathbf{R}} (\tilde{\mathbf{a}} - \bar{\mathbf{b}}_a) + \mathbf{g} \\
\dot{\bar{\mathbf{R}}} &= \bar{\mathbf{R}} [\tilde{\boldsymbol{\omega}} - \bar{\mathbf{b}}_g]_\times \\
\dot{\bar{\mathbf{b}}}_a &= \mathbf{0} \\
\dot{\bar{\mathbf{b}}}_g &= \mathbf{0}
\end{aligned}
$$

**误差状态预测**（线性）：
$$
\delta\dot{\mathbf{x}} = \mathbf{F} \delta\mathbf{x} + \mathbf{G} \mathbf{n}
$$

其中状态转移矩阵：
$$
\mathbf{F} = \begin{bmatrix}
\mathbf{0} & \mathbf{I} & \mathbf{0} & \mathbf{0} & \mathbf{0} \\
\mathbf{0} & \mathbf{0} & -[\bar{\mathbf{R}}(\tilde{\mathbf{a}} - \bar{\mathbf{b}}_a)]_\times & -\bar{\mathbf{R}} & \mathbf{0} \\
\mathbf{0} & \mathbf{0} & -[\tilde{\boldsymbol{\omega}} - \bar{\mathbf{b}}_g]_\times & \mathbf{0} & -\mathbf{I} \\
\mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{0} \\
\mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{0}
\end{bmatrix}
$$

噪声驱动矩阵：
$$
\mathbf{G} = \begin{bmatrix}
\mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{0} \\
-\bar{\mathbf{R}} & \mathbf{0} & \mathbf{0} & \mathbf{0} \\
\mathbf{0} & -\mathbf{I} & \mathbf{0} & \mathbf{0} \\
\mathbf{0} & \mathbf{0} & \mathbf{I} & \mathbf{0} \\
\mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{I}
\end{bmatrix}
$$

过程噪声协方差：
$$
\mathbf{Q} = \text{diag}(\sigma_{a}^2, \sigma_{g}^2, \sigma_{b_a}^2, \sigma_{b_g}^2)
$$

#### 更新步骤

**观测模型**（以视觉重投影为例）：
$$
\mathbf{z} = h(\mathbf{x}) + \mathbf{v} = \pi(\mathbf{R}^T (\mathbf{p}_f - \mathbf{p}) + \mathbf{p}_c) + \mathbf{v}
$$

**误差状态观测模型**：
$$
\delta\mathbf{z} = \mathbf{H} \delta\mathbf{x} + \mathbf{v}
$$

其中雅可比矩阵：
$$
\mathbf{H} = \begin{bmatrix} \mathbf{H}_{\mathbf{p}} & \mathbf{0} & \mathbf{H}_{\mathbf{R}} & \mathbf{0} & \mathbf{0} \end{bmatrix}
$$

**卡尔曼增益**：
$$
\mathbf{K} = \mathbf{P} \mathbf{H}^T (\mathbf{H} \mathbf{P} \mathbf{H}^T + \mathbf{R})^{-1}
$$

**误差状态更新**：
$$
\delta\mathbf{x} = \mathbf{K} (\mathbf{z} - h(\bar{\mathbf{x}}))
$$

**名义状态更新**：
$$
\begin{aligned}
\bar{\mathbf{p}} &\leftarrow \bar{\mathbf{p}} + \delta\mathbf{p} \\
\bar{\mathbf{v}} &\leftarrow \bar{\mathbf{v}} + \delta\mathbf{v} \\
\bar{\mathbf{R}} &\leftarrow \bar{\mathbf{R}} \exp(\boldsymbol{\theta}^\wedge) \\
\bar{\mathbf{b}}_a &\leftarrow \bar{\mathbf{b}}_a + \delta\mathbf{b}_a \\
\bar{\mathbf{b}}_g &\leftarrow \bar{\mathbf{b}}_g + \delta\mathbf{b}_g
\end{aligned}
$$

**协方差更新**：
$$
\mathbf{P} = (\mathbf{I} - \mathbf{K} \mathbf{H}) \mathbf{P}
$$

**误差状态重置**：
$$
\delta\mathbf{x} \leftarrow \mathbf{0}
$$

### 3.4 误差状态 EKF 的优势

1. **误差状态始终是小量**：线性化更准确
2. **旋转处理自然**：使用李群/李代数，避免奇异性
3. **协方差矩阵有界**：误差状态的协方差不会无限增长
4. **数值稳定性好**：适合长时间运行

---

## 4. IMU 预积分与预测

### 4.1 离散时间 IMU 模型

**连续时间模型**：
$$
\begin{aligned}
\dot{\mathbf{p}} &= \mathbf{v} \\
\dot{\mathbf{v}} &= \mathbf{R} (\tilde{\mathbf{a}} - \mathbf{b}_a - \mathbf{n}_a) + \mathbf{g} \\
\dot{\mathbf{R}} &= \mathbf{R} [\tilde{\boldsymbol{\omega}} - \mathbf{b}_g - \mathbf{n}_g]_\times \\
\dot{\mathbf{b}}_a &= \mathbf{n}_{b_a} \\
\dot{\mathbf{b}}_g &= \mathbf{n}_{b_g}
\end{aligned}
$$

**离散时间模型**（一阶近似）：
$$
\begin{aligned}
\mathbf{p}_{k+1} &= \mathbf{p}_k + \mathbf{v}_k \Delta t + \frac{1}{2} \mathbf{R}_k (\tilde{\mathbf{a}}_k - \mathbf{b}_{a_k}) \Delta t^2 + \frac{1}{2} \mathbf{g} \Delta t^2 \\
\mathbf{v}_{k+1} &= \mathbf{v}_k + \mathbf{R}_k (\tilde{\mathbf{a}}_k - \mathbf{b}_{a_k}) \Delta t + \mathbf{g} \Delta t \\
\mathbf{R}_{k+1} &= \mathbf{R}_k \exp([(\tilde{\boldsymbol{\omega}}_k - \mathbf{b}_{g_k}) \Delta t]_\times) \\
\mathbf{b}_{a_{k+1}} &= \mathbf{b}_{a_k} \\
\mathbf{b}_{g_{k+1}} &= \mathbf{b}_{g_k}
\end{aligned}
$$

### 4.2 IMU 预积分理论

#### 预积分量的定义

在时间区间 $[t_i, t_j]$ 上，定义预积分量（与 bias 无关）：

**位移预积分**：
$$
\hat{\boldsymbol{\alpha}}_{ij} = \sum_{k=i}^{j-1} \left( \hat{\boldsymbol{\beta}}_{ik} \Delta t_k + \frac{1}{2} \hat{\mathbf{R}}_{ik} (\tilde{\mathbf{a}}_k - \tilde{\mathbf{b}}_{a_i}) \Delta t_k^2 \right)
$$

**速度预积分**：
$$
\hat{\boldsymbol{\beta}}_{ij} = \sum_{k=i}^{j-1} \hat{\mathbf{R}}_{ik} (\tilde{\mathbf{a}}_k - \tilde{\mathbf{b}}_{a_i}) \Delta t_k
$$

**旋转预积分**：
$$
\hat{\boldsymbol{\gamma}}_{ij} = \bigotimes_{k=i}^{j-1} \exp([(\tilde{\boldsymbol{\omega}}_k - \tilde{\mathbf{b}}_{g_i}) \Delta t]_\times)
$$

其中 $\hat{\mathbf{R}}_{ik} = \hat{\boldsymbol{\gamma}}_{ik}$。

#### 状态传播

使用预积分量，从帧 $i$ 到帧 $j$ 的状态传播：

$$
\begin{aligned}
\mathbf{p}_j &= \mathbf{p}_i + \mathbf{v}_i \Delta t_{ij} + \frac{1}{2} \mathbf{g} \Delta t_{ij}^2 + \mathbf{R}_i \hat{\boldsymbol{\alpha}}_{ij} \\
\mathbf{v}_j &= \mathbf{v}_i + \mathbf{g} \Delta t_{ij} + \mathbf{R}_i \hat{\boldsymbol{\beta}}_{ij} \\
\mathbf{R}_j &= \mathbf{R}_i \hat{\boldsymbol{\gamma}}_{ij}
\end{aligned}
$$

#### Bias 更新的一阶近似

当 bias 从 $\tilde{\mathbf{b}}$ 变为 $\tilde{\mathbf{b}} + \delta\mathbf{b}$ 时，预积分量的线性化更新：

$$
\begin{aligned}
\boldsymbol{\alpha}_{ij} &\approx \hat{\boldsymbol{\alpha}}_{ij} + \mathbf{J}_{b_a}^{\alpha} \delta\mathbf{b}_a + \mathbf{J}_{b_g}^{\alpha} \delta\mathbf{b}_g \\
\boldsymbol{\beta}_{ij} &\approx \hat{\boldsymbol{\beta}}_{ij} + \mathbf{J}_{b_a}^{\beta} \delta\mathbf{b}_a + \mathbf{J}_{b_g}^{\beta} \delta\mathbf{b}_g \\
\boldsymbol{\gamma}_{ij} &\approx \hat{\boldsymbol{\gamma}}_{ij} \otimes \exp(\mathbf{J}_{b_g}^{\gamma} \delta\mathbf{b}_g)
\end{aligned}
$$

其中雅可比矩阵的递推公式：

$$
\begin{aligned}
\mathbf{J}_{b_a, k+1}^{\alpha} &= \mathbf{J}_{b_a, k}^{\alpha} + \mathbf{J}_{b_a, k}^{\beta} \Delta t_k - \frac{1}{2} \hat{\mathbf{R}}_{ik} \Delta t_k^2 \\
\mathbf{J}_{b_g, k+1}^{\alpha} &= \mathbf{J}_{b_g, k}^{\alpha} + \mathbf{J}_{b_g, k}^{\beta} \Delta t_k - \hat{\mathbf{R}}_{ik} [\tilde{\mathbf{a}}_k - \tilde{\mathbf{b}}_{a_i}]_\times \mathbf{J}_{b_g, k}^{\gamma} \Delta t_k^2 \\
\mathbf{J}_{b_a, k+1}^{\beta} &= \mathbf{J}_{b_a, k}^{\beta} - \hat{\mathbf{R}}_{ik} \Delta t_k \\
\mathbf{J}_{b_g, k+1}^{\beta} &= \mathbf{J}_{b_g, k}^{\beta} - \hat{\mathbf{R}}_{ik} [\tilde{\mathbf{a}}_k - \tilde{\mathbf{b}}_{a_i}]_\times \mathbf{J}_{b_g, k}^{\gamma} \Delta t_k \\
\mathbf{J}_{b_g, k+1}^{\gamma} &= \mathbf{J}_{b_g, k}^{\gamma} - \mathbf{J}_{r}(\cdot) \Delta t_k
\end{aligned}
$$

初始值：$\mathbf{J}_{b_a, i}^{\alpha} = \mathbf{0}$, $\mathbf{J}_{b_g, i}^{\alpha} = \mathbf{0}$, $\mathbf{J}_{b_a, i}^{\beta} = \mathbf{0}$, $\mathbf{J}_{b_g, i}^{\beta} = \mathbf{0}$, $\mathbf{J}_{b_g, i}^{\gamma} = \mathbf{0}$

#### 协方差传播

预积分量的协方差矩阵 $\mathbf{P}_{ij}^{\mathcal{I}}$（15×15）：

$$
\mathbf{P}_{k+1}^{\mathcal{I}} = \mathbf{A}_k \mathbf{P}_k^{\mathcal{I}} \mathbf{A}_k^T + \mathbf{B}_k \mathbf{Q}_k \mathbf{B}_k^T
$$

其中状态转移矩阵：
$$
\mathbf{A}_k = \begin{bmatrix}
\mathbf{I} & \mathbf{I} \Delta t_k & \mathbf{0} & -\frac{1}{2} \hat{\mathbf{R}}_{ik} \Delta t_k^2 & \mathbf{0} \\
\mathbf{0} & \mathbf{I} & -\hat{\mathbf{R}}_{ik} [\tilde{\mathbf{a}}_k - \tilde{\mathbf{b}}_{a_i}]_\times \Delta t_k & -\hat{\mathbf{R}}_{ik} \Delta t_k & \mathbf{0} \\
\mathbf{0} & \mathbf{0} & \mathbf{I} & \mathbf{0} & -\mathbf{I} \Delta t_k \\
\mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{I} & \mathbf{0} \\
\mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{I}
\end{bmatrix}
$$

噪声驱动矩阵：
$$
\mathbf{B}_k = \begin{bmatrix}
\mathbf{0} & \frac{1}{2} \hat{\mathbf{R}}_{ik} \Delta t_k^2 & \mathbf{0} & \mathbf{0} \\
\mathbf{0} & \hat{\mathbf{R}}_{ik} \Delta t_k & \mathbf{0} & \mathbf{0} \\
\mathbf{J}_{r}(\cdot) & \mathbf{0} & \mathbf{I} \Delta t_k & \mathbf{0} \\
\mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{I} \Delta t_k \\
\mathbf{0} & \mathbf{0} & \mathbf{0} & \mathbf{I} \Delta t_k
\end{bmatrix}
$$

过程噪声协方差：
$$
\mathbf{Q}_k = \text{diag}(\sigma_g^2, \sigma_a^2, \sigma_{b_g}^2, \sigma_{b_a}^2) / \Delta t_k
$$

### 4.3 预积分的优势

1. **避免重复积分**：当 bias 更新时，不需要重新积分
2. **计算效率高**：预积分量可以递推计算
3. **便于边缘化**：预积分量可以作为约束直接用于优化或滤波
4. **数值稳定**：使用四元数表示旋转，避免奇异性

---

## 5. MSCKF 多状态约束滤波

### 5.1 MSCKF 的核心思想

**传统 EKF-SLAM**：将 landmark 加入状态向量，状态维度随地图增长

**MSCKF**：
- 状态向量只包含相机位姿（多状态约束）
- Landmark 不在状态向量中，而是通过几何约束消去
- 状态维度固定，计算效率高

### 5.2 MSCKF 的状态向量

$$
\mathbf{x} = \begin{bmatrix} \mathbf{x}_I^T & \mathbf{x}_{C_1}^T & \mathbf{x}_{C_2}^T & \cdots & \mathbf{x}_{C_N}^T \end{bmatrix}^T
$$

其中：
- $\mathbf{x}_I = [\mathbf{p}_I^T, \mathbf{q}_I^T, \mathbf{b}_a^T, \mathbf{b}_g^T]^T$：IMU 状态（23 维误差状态）
- $\mathbf{x}_{C_i} = [\mathbf{p}_{C_i}^T, \mathbf{q}_{C_i}^T]^T$：第 $i$ 个相机位姿（12 维误差状态）

总状态维度：$23 + 12N$（误差状态）

### 5.3 MSCKF 的算法流程

#### 1. IMU 预测（Propagation）

当收到 IMU 数据时：
- 更新名义状态（使用 IMU 运动学方程）
- 更新误差状态协方差（使用状态转移矩阵）

#### 2. 状态增广（State Augmentation）

当收到新图像时：
- 将当前 IMU 状态复制到状态向量末尾
- 更新协方差矩阵（新增行和列）

$$
\mathbf{x} \leftarrow \begin{bmatrix} \mathbf{x} \\ \mathbf{x}_{C_{N+1}} \end{bmatrix}, \quad
\mathbf{P} \leftarrow \begin{bmatrix} \mathbf{P} & \mathbf{P} \mathbf{J}^T \\ \mathbf{J} \mathbf{P} & \mathbf{J} \mathbf{P} \mathbf{J}^T \end{bmatrix}
$$

其中 $\mathbf{J}$ 是从 IMU 状态到相机状态的雅可比矩阵。

#### 3. 视觉量测更新（Measurement Update）

对于每个跟踪结束的 landmark $f$：
- 收集所有观测到该 landmark 的相机位姿 $\{\mathbf{x}_{C_i}\}_{i \in \mathcal{S}_f}$
- 构建约束方程
- 进行卡尔曼更新

### 5.4 MSCKF 的几何约束

#### 单目约束

对于 landmark $f$，在相机 $i$ 中的观测：

$$
\mathbf{z}_{f,i} = \pi(\mathbf{R}_{C_i}^T (\mathbf{p}_f - \mathbf{p}_{C_i})) + \mathbf{n}_{f,i}
$$

其中 $\mathbf{p}_f$ 是 landmark 的位置（未知）。

**消去 landmark**：

选择第一个相机 $C_1$ 作为参考，将 $\mathbf{p}_f$ 表示为：

$$
\mathbf{p}_f = \mathbf{p}_{C_1} + \mathbf{R}_{C_1} \pi^{-1}(\mathbf{z}_{f,1}) d_f
$$

其中 $d_f$ 是 landmark 在相机 $C_1$ 中的深度（未知标量）。

代入其他相机的观测方程：

$$
\mathbf{z}_{f,i} = \pi(\mathbf{R}_{C_i}^T (\mathbf{p}_{C_1} - \mathbf{p}_{C_i} + \mathbf{R}_{C_1} \pi^{-1}(\mathbf{z}_{f,1}) d_f)) + \mathbf{n}_{f,i}
$$

这是关于 $d_f$ 的非线性方程，可以通过优化求解。

#### 约束的线性化

定义残差：

$$
\mathbf{r}_{f,i} = \mathbf{z}_{f,i} - \pi(\mathbf{R}_{C_i}^T (\mathbf{p}_{C_1} - \mathbf{p}_{C_i} + \mathbf{R}_{C_1} \pi^{-1}(\mathbf{z}_{f,1}) \hat{d}_f))
$$

对状态 $\mathbf{x}$ 线性化：

$$
\mathbf{r}_{f,i} \approx \mathbf{H}_{f,i} \delta\mathbf{x} + \mathbf{n}_{f,i}
$$

将所有相机的约束堆叠：

$$
\mathbf{r}_f = \mathbf{H}_f \delta\mathbf{x} + \mathbf{n}_f
$$

#### 左零空间投影（Null-space Projection）

为了进一步提高数值稳定性，对 $\mathbf{H}_f$ 进行 QR 分解：

$$
\mathbf{H}_f^T = \mathbf{Q} \begin{bmatrix} \mathbf{R} \\ \mathbf{0} \end{bmatrix}
$$

取左零空间投影：

$$
\mathbf{H}_f' = \mathbf{Q}_2^T \mathbf{H}_f, \quad \mathbf{r}_f' = \mathbf{Q}_2^T \mathbf{r}_f
$$

其中 $\mathbf{Q}_2$ 是 $\mathbf{Q}$ 的后半部分（对应零空间）。

投影后的约束：
- 维度降低（消去了 landmark 的维度）
- 数值更稳定
- 保留了所有信息

### 5.5 MSCKF 的优势

1. **状态维度固定**：不随地图大小增长
2. **计算效率高**：避免了 landmark 状态的维护
3. **一致性好**：使用 FEJ (First Estimate Jacobian) 避免不一致
4. **适合实时系统**：计算复杂度可控

### 5.6 MSCKF 的局限

1. **不能回环检测**：没有地图，无法进行回环检测
2. **漂移累积**：没有全局约束，误差会累积
3. ** landmark 利用率低**：只使用跟踪结束的 landmark

---

## 6. 视觉量测更新

### 6.1 相机观测模型

**针孔相机模型**：

$$
\mathbf{z} = \pi(\mathbf{p}_c) = \begin{bmatrix} f_x \frac{X_c}{Z_c} + c_x \\ f_y \frac{Y_c}{Z_c} + c_y \end{bmatrix}
$$

其中 $\mathbf{p}_c = [X_c, Y_c, Z_c]^T$ 是相机坐标系下的 3D 点。

**相机坐标系转换**：

$$
\mathbf{p}_c = \mathbf{R}_{CI} (\mathbf{R}_{WI}^T (\mathbf{p}_f - \mathbf{p}_I) - \mathbf{p}_C^I)
$$

### 6.2 雅可比矩阵推导

#### 对 IMU 位姿的雅可比

$$
\mathbf{H}_{I} = \begin{bmatrix} \mathbf{H}_{\mathbf{p}_I} & \mathbf{H}_{\boldsymbol{\theta}_I} & \mathbf{0} & \mathbf{0} \end{bmatrix}
$$

**对位置的雅可比**：

$$
\mathbf{H}_{\mathbf{p}_I} = -\frac{\partial \pi}{\partial \mathbf{p}_c} \mathbf{R}_{CI} \mathbf{R}_{WI}^T
$$

**对旋转的雅可比**：

$$
\mathbf{H}_{\boldsymbol{\theta}_I} = \frac{\partial \pi}{\partial \mathbf{p}_c} \mathbf{R}_{CI} [\mathbf{R}_{WI}^T (\mathbf{p}_f - \mathbf{p}_I)]_\times
$$

#### 对相机位姿的雅可比

$$
\mathbf{H}_{C_i} = \begin{bmatrix} \mathbf{H}_{\mathbf{p}_{C_i}} & \mathbf{H}_{\boldsymbol{\theta}_{C_i}} \end{bmatrix}
$$

**对相机位置的雅可比**：

$$
\mathbf{H}_{\mathbf{p}_{C_i}} = -\frac{\partial \pi}{\partial \mathbf{p}_c} \mathbf{R}_{CI} \mathbf{R}_{WI}^T
$$

**对相机旋转的雅可比**：

$$
\mathbf{H}_{\boldsymbol{\theta}_{C_i}} = \frac{\partial \pi}{\partial \mathbf{p}_c} [\mathbf{p}_c]_\times
$$

### 6.3 投影雅可比矩阵

$$
\frac{\partial \pi}{\partial \mathbf{p}_c} = \begin{bmatrix} \frac{f_x}{Z_c} & 0 & -\frac{f_x X_c}{Z_c^2} \\ 0 & \frac{f_y}{Z_c} & -\frac{f_y Y_c}{Z_c^2} \end{bmatrix}
$$

### 6.4 卡尔曼更新步骤

#### 1. 构建量测方程

对于 landmark $f$，在所有观测相机中的残差：

$$
\mathbf{r}_f = \begin{bmatrix} \mathbf{r}_{f,1} \\ \mathbf{r}_{f,2} \\ \vdots \\ \mathbf{r}_{f,N_f} \end{bmatrix}, \quad
\mathbf{H}_f = \begin{bmatrix} \mathbf{H}_{f,1} \\ \mathbf{H}_{f,2} \\ \vdots \\ \mathbf{H}_{f,N_f} \end{bmatrix}
$$

#### 2. 左零空间投影

对 $\mathbf{H}_f$ 进行 QR 分解，取左零空间投影：

$$
\mathbf{H}_f' = \mathbf{Q}_2^T \mathbf{H}_f, \quad \mathbf{r}_f' = \mathbf{Q}_2^T \mathbf{r}_f
$$

#### 3. 卡尔曼增益

$$
\mathbf{K}_f = \mathbf{P} \mathbf{H}_f'^T (\mathbf{H}_f' \mathbf{P} \mathbf{H}_f'^T + \sigma_{pix}^2 \mathbf{I})^{-1}
$$

#### 4. 状态更新

$$
\delta\mathbf{x} = \mathbf{K}_f \mathbf{r}_f'
$$

$$
\mathbf{P} = (\mathbf{I} - \mathbf{K}_f \mathbf{H}_f') \mathbf{P}
$$

#### 5. 名义状态更新

$$
\bar{\mathbf{x}} \leftarrow \bar{\mathbf{x}} \oplus \delta\mathbf{x}
$$

### 6.5 批处理更新 vs 序列更新

**批处理更新**：
- 将所有 landmark 的约束堆叠成一个大的量测方程
- 一次性更新
- 计算效率高（矩阵求维数高）

**序列更新**：
- 逐个 landmark 更新
- 每次更新后协方差矩阵变小
- 计算效率低（多次矩阵求逆）

**OpenVINS 采用批处理更新**。

---

## 7. 状态增广与边缘化

### 7.1 状态增广

当收到新图像时，将当前 IMU 状态复制到状态向量：

**增广前的状态**：
$$
\mathbf{x} = \begin{bmatrix} \mathbf{x}_I \\ \mathbf{x}_{C_1} \\ \vdots \\ \mathbf{x}_{C_N} \end{bmatrix}, \quad
\mathbf{P} = \begin{bmatrix} \mathbf{P}_{II} & \mathbf{P}_{IC_1} & \cdots & \mathbf{P}_{IC_N} \\ \mathbf{P}_{C_1I} & \mathbf{P}_{C_1C_1} & \cdots & \mathbf{P}_{C_1C_N} \\ \vdots & \vdots & \ddots & \vdots \\ \mathbf{P}_{C_NI} & \mathbf{P}_{C_NC_1} & \cdots & \mathbf{P}_{C_NC_N} \end{bmatrix}
$$

**增广后的状态**：
$$
\mathbf{x}' = \begin{bmatrix} \mathbf{x} \\ \mathbf{x}_{C_{N+1}} \end{bmatrix}
$$

**增广后的协方差**：
$$
\mathbf{P}' = \begin{bmatrix} \mathbf{P} & \mathbf{P} \mathbf{J}^T \\ \mathbf{J} \mathbf{P} & \mathbf{J} \mathbf{P} \mathbf{J}^T \end{bmatrix}
$$

其中 $\mathbf{J}$ 是从 IMU 状态到相机状态的转换雅可比：

$$
\mathbf{J} = \begin{bmatrix} \mathbf{I}_{6 \times 6} & \mathbf{0} & \cdots & \mathbf{0} \end{bmatrix}
$$

（假设相机和 IMU 是刚体连接，外参已知）

### 7.2 状态边缘化

为了控制状态维度，需要边缘化旧的相机位姿。

#### 边缘化策略

**FIFO (First-In-First-Out)**：
- 边缘化最老的相机位姿
- 简单，但可能丢失有用信息

**基于距离**：
- 边缘化与当前位姿距离最远的相机
- 保留关键帧

**基于视差**：
- 边缘化视差最小的相机
- 保留信息量大的关键帧

#### 边缘化的数学

将状态分为要保留的 $\mathbf{x}_a$ 和要边缘化的 $\mathbf{x}_b$：

$$
\mathbf{P} = \begin{bmatrix} \mathbf{P}_{aa} & \mathbf{P}_{ab} \\ \mathbf{P}_{ba} & \mathbf{P}_{bb} \end{bmatrix}
$$

边缘化后的协方差（Schur 补）：

$$
\mathbf{P}_{a|b} = \mathbf{P}_{aa} - \mathbf{P}_{ab} \mathbf{P}_{bb}^{-1} \mathbf{P}_{ba}
$$

### 7.3 FEJ (First Estimate Jacobian)

#### 问题

在边缘化时，如果使用当前估计的雅可比，会导致"一致性过约"(over-commitment)问题：
- 边缘化时的线性化点与后续更新时的线性化点不同
- 导致估计不一致（协方差过于乐观）

#### 解决方案

**FEJ (First Estimate Jacobian)**：
- 边缘化时使用**首次估计时的雅可比**
- 后续更新时也使用相同的雅可比
- 保持一致性

#### FEJ 的实现

在 OpenVINS 中：
- 每个状态保存首次估计时的值
- 计算雅可比时使用首次估计的值
- 状态更新后，首次估计值不变

```cpp
// 伪代码
class IMUState {
    State estimate;        // 当前估计
    State first_estimate;  // 首次估计（用于 FEJ）
    
    Jacobian computeJacobian() {
        // 使用 first_estimate 计算雅可比
        return computeJ(first_estimate);
    }
    
    void update(const Delta& delta) {
        estimate = estimate ⊕ delta;
        // first_estimate 不变
    }
};
```

### 7.4 边缘化引入的先验

边缘化后，会引入一个先验约束：

$$
\mathbf{r}_{prior} = \mathbf{H}_{prior} \delta\mathbf{x}_a + \mathbf{n}_{prior}
$$

其中：
- $\mathbf{H}_{prior}$：先验的雅可比矩阵
- $\mathbf{n}_{prior} \sim \mathcal{N}(\mathbf{0}, \mathbf{P}_{a|b})$：先验噪声

这个先验在后续的量测更新中需要一直保留。

---

## 8. 滤波 vs 优化

### 8.1 滤波方法（如 MSCKF）

**优点**：
- 计算效率高（固定状态维度）
- 实时性好（增量更新）
- 内存占用小（不需要存储所有历史状态）
- 适合嵌入式系统

**缺点**：
- 不能回环检测（没有全局地图）
- 误差会累积（没有全局优化）
- 线性化误差（EKF 的固有缺陷）
- 一致性难以保证（需要 FEJ 等技巧）

### 8.2 优化方法（如 VINS-Mono）

**优点**：
- 精度高（多次迭代线性化）
- 可以回环检测（有全局地图）
- 一致性好（最大后验估计）
- 可以融合多种约束

**缺点**：
- 计算效率低（需要求解大规模线性系统）
- 内存占用大（需要存储所有关键帧）
- 实时性差（需要多次迭代）
- 实现复杂（需要处理稀疏性、边缘化等）

### 8.3 混合方法

**滑动窗口优化**：
- 只优化最近的关键帧（滑动窗口）
- 边缘化旧的关键帧（引入先验）
- 结合滤波和优化的优点

**代表系统**：
- VINS-Mono：滑动窗口优化 + 边缘化
- OKVIS：滑动窗口优化
- BASALT：滑动窗口优化

### 8.4 选择建议

| 应用场景 | 推荐方法 | 理由 |
|---------|---------|------|
| 实时嵌入式系统 | MSCKF | 计算效率高，内存占用小 |
| 高精度离线处理 | 优化方法 | 精度高，可以回环 |
| 长时间运行 | 滑动窗口优化 | 平衡精度和效率 |
| 资源受限 | MSCKF | 内存和计算要求低 |
| 需要回环检测 | 优化方法 | 有全局地图 |

---

## 9. 实战应用

### 9.1 OpenVINS 架构

OpenVINS 是基于 MSCKF 的开源 VIO 系统，核心模块：

```
OpenVINS
├── ov_core/          # 核心数据结构
├── ov_init/          # 初始化模块
├── ov_msckf/         # MSCKF 估计器
│   ├── State.h       # 状态定义
│   ├── Updater.h     # 更新器基类
│   ├── UpdaterMSCKF  # MSCKF 更新
│   ├── UpdaterSLAM   # SLAM 更新（可选）
│   └── Propagator    # IMU 传播
├── ov_eval/          # 评估工具
└── ov_data/          # 数据类型
```

### 9.2 关键数据结构

#### 状态类 (State)

```cpp
class State {
    // IMU 状态
    VecVector3d _imu_pos;      // 位置
    VecVector4d _imu_quat;     // 四元数
    VecVector3d _imu_vel;      // 速度
    VecVector3d _imu_bg;       // 陀螺仪 bias
    VecVector3d _imu_ba;       // 加速度计 bias
    
    // 相机位姿（多状态）
    vector<Type*> _clones;     // 历史相机位姿
    
    // 协方差矩阵
    MatrixXd _Cov;             // 状态协方差
    
    // FEJ 值
    map<Type*, VecVector4d> _fej;  // 首次估计
};
```

#### 类型类 (Type)

```cpp
class Type {
    int _id;                   // 状态 ID
    int _size;                 // 状态维度
    int _dim;                  // 误差状态维度
    VecVector1d _value;        // 名义值
    VecVector1d _fej;          // FEJ 值（首次估计）
};
```

### 9.3 核心算法流程

#### 1. IMU 传播 (Propagator)

```cpp
void propagator::propagate(State* state, double timestamp) {
    // 1. 收集 IMU 数据
    vector<ImuData> imu_data = get_imu_data(state->_timestamp, timestamp);
    
    // 2. 预积分
    for (auto imu : imu_data) {
        // 更新名义状态
        state->_imu_pos += state->_imu_vel * dt + 0.5 * gravity * dt * dt 
                         + 0.5 * state->_imu_quat.toRotationMatrix() * (imu.acc - state->_imu_ba) * dt * dt;
        state->_imu_vel += gravity * dt 
                         + state->_imu_quat.toRotationMatrix() * (imu.acc - state->_imu_ba) * dt;
        state->_imu_quat = state->_imu_quat * delta_q((imu.gyr - state->_imu_bg) * dt);
        
        // 更新协方差
        MatrixXd F = compute_state_transition_matrix(state, imu);
        MatrixXd Q = compute_process_noise(state, imu);
        state->_Cov = F * state->_Cov * F.transpose() + Q;
    }
    
    state->_timestamp = timestamp;
}
```

#### 2. 状态增广

```cpp
void state_augmentation(State* state, double timestamp) {
    // 1. 创建新的相机位姿类型
    Type* new_clone = new TypePose();
    new_clone->_value = state->_imu_pos;  // 复制 IMU 位姿
    new_clone->_fej = state->_imu_pos;    // FEJ 值
    new_clone->_id = state->_clones.size();
    
    // 2. 增广协方差矩阵
    MatrixXd J = compute_jacobian(state);  // IMU 到相机的雅可比
    MatrixXd new_cov = MatrixXd::Zero(state->_Cov.rows() + 12, state->_Cov.cols() + 12);
    
    new_cov.block(0, 0, state->_Cov.rows(), state->_Cov.cols()) = state->_Cov;
    new_cov.block(state->_Cov.rows(), 0, 12, state->_Cov.cols()) = J * state->_Cov;
    new_cov.block(0, state->_Cov.cols(), state->_Cov.rows(), 12) = state->_Cov * J.transpose();
    new_cov.block(state->_Cov.rows(), state->_Cov.cols(), 12, 12) = J * state->_Cov * J.transpose();
    
    state->_Cov = new_cov;
    state->_clones.push_back(new_clone);
}
```

#### 3. MSCKF 更新

```cpp
void updater_msckf::update(State* state, const vector<Feature>& features) {
    // 1. 对每个特征构建约束
    MatrixXd H_total;
    VectorXd r_total;
    
    for (auto feature : features) {
        // 收集观测
        vector<pair<int, Vector2d>> observations = feature.observations;
        
        // 构建雅可比矩阵
        MatrixXd H_f = compute_jacobian(state, observations);
        VectorXd r_f = compute_residual(state, observations);
        
        // 左零空间投影
        MatrixXd H_proj, r_proj;
        nullspace_project(H_f, r_f, H_proj, r_proj);
        
        // 堆叠
        H_total.conservativeResize(H_total.rows() + H_proj.rows(), H_total.cols());
        r_total.conservativeResize(r_total.size() + r_proj.size());
        H_total.bottomRows(H_proj.rows()) = H_proj;
        r_total.tail(r_proj.size()) = r_proj;
    }
    
    // 2. 卡尔曼更新
    MatrixXd K = state->_Cov * H_total.transpose() * 
                 (H_total * state->_Cov * H_total.transpose() + R).inverse();
    VectorXd dx = K * r_total;
    state->_Cov = (MatrixXd::Identity(state->_Cov.rows(), state->_Cov.cols()) - K * H_total) * state->_Cov;
    
    // 3. 状态更新
    state->update(dx);
}
```

#### 4. 边缘化

```cpp
void marginalize(State* state, int clone_id) {
    // 1. 找到要边缘化的状态
    Type* clone = state->_clones[clone_id];
    
    // 2. 重新排序状态（要边缘化的放最后）
    reorder_state(state, clone_id);
    
    // 3. Schur 补
    int m = clone->_dim;  // 要边缘化的维度
    int n = state->_Cov.rows() - m;  // 要保留的维度
    
    MatrixXd P_aa = state->_Cov.block(0, 0, n, n);
    MatrixXd P_ab = state->_Cov.block(0, n, n, m);
    MatrixXd P_ba = state->_Cov.block(n, 0, m, n);
    MatrixXd P_bb = state->_Cov.block(n, n, m, m);
    
    MatrixXd P_marg = P_aa - P_ab * P_bb.inverse() * P_ba;
    
    // 4. 更新协方差
    state->_Cov = P_marg;
    
    // 5. 删除状态
    state->_clones.erase(state->_clones.begin() + clone_id);
    delete clone;
}
```

### 9.4 调试技巧

#### 1. 检查协方差矩阵

```cpp
// 检查协方差矩阵是否正定
Eigen::SelfAdjointEigenSolver<MatrixXd> eig(state->_Cov);
VectorXd eigenvalues = eig.eigenvalues();

if (eigenvalues.minCoeff() < 0) {
    LOG(ERROR) << "协方差矩阵非正定！最小特征值: " << eigenvalues.minCoeff();
}

if (eigenvalues.maxCoeff() / eigenvalues.minCoeff() > 1e6) {
    LOG(WARNING) << "协方差矩阵条件数过大: " 
                 << eigenvalues.maxCoeff() / eigenvalues.minCoeff();
}
```

#### 2. 检查新息

```cpp
// 检查新息是否在合理范围内
VectorXd innovation = z - H * x_pred;
MatrixXd S = H * P * H.transpose() + R;

double nis = innovation.transpose() * S.inverse() * innovation;
double threshold = chi2_inv_cdf(0.95, z.rows());

if (nis > threshold) {
    LOG(WARNING) << "新息过大，NIS: " << nis << " > " << threshold;
}
```

#### 3. 检查 FEJ 一致性

```cpp
// 检查 FEJ 值和当前估计的差异
for (auto clone : state->_clones) {
    VectorXd diff = clone->_value - clone->_fej;
    if (diff.norm() > 0.1) {  // 阈值根据具体问题调整
        LOG(WARNING) << "FEJ 不一致，Clone " << clone->_id 
                     << " 差异: " << diff.norm();
    }
}
```

### 9.5 常见问题与解决

#### 问题 1：协方差矩阵不正定

**原因**：
- 数值误差累积
- 边缘化实现错误
- 噪声参数设置不当

**解决**：
- 定期重新计算协方差
- 检查边缘化的 Schur 补
- 调整噪声参数

#### 问题 2：估计发散

**原因**：
- IMU 噪声参数过大
- 外参标定错误
- 时间同步问题

**解决**：
- 重新标定 IMU 噪声参数
- 检查外参
- 检查时间同步

#### 问题 3：轨迹漂移

**原因**：
- bias 估计不准
- 边缘化引入误差
- 没有回环检测

**解决**：
- 改进 bias 估计
- 使用更好的边缘化策略
- 考虑使用优化方法

---

## 10. 滤波诊断指标与问题排查

滤波方法中有许多诊断指标可以帮助排查问题，类似于优化方法中的 Hessian 矩阵分析。这些指标可以检测滤波器的健康状态、一致性和性能。

### 10.1 新息与 NIS (Normalized Innovation Squared)

#### 理论基础

**新息 (Innovation)** 是观测值与预测值的差异：

$$
\tilde{\mathbf{y}}_k = \mathbf{z}_k - h(\hat{\mathbf{x}}_{k|k-1})
$$

**新息协方差**：

$$
\mathbf{S}_k = \mathbf{H}_k \mathbf{P}_{k|k-1} \mathbf{H}_k^T + \mathbf{R}_k
$$

**NIS (归一化新息平方)**：

$$
\text{NIS}_k = \tilde{\mathbf{y}}_k^T \mathbf{S}_k^{-1} \tilde{\mathbf{y}}_k
$$

#### 统计特性

如果滤波器一致（consistent），NIS 应该服从卡方分布：

$$
\text{NIS}_k \sim \chi^2(m)
$$

其中 $m$ 是观测向量的维度。

#### 诊断阈值

对于 $m$ 维观测，在 95% 置信水平下：

| 观测维度 $m$ | $\chi^2_{0.025}$ | $\chi^2_{0.975}$ | 合理范围 |
|-------------|------------------|------------------|---------|
| 2 (2D视觉) | 0.0506 | 7.378 | [0.05, 7.4] |
| 3 (3D视觉) | 0.216 | 9.348 | [0.2, 9.3] |
| 6 (双目) | 1.237 | 14.449 | [1.2, 14.4] |
| 15 (IMU) | 6.262 | 27.488 | [6.3, 27.5] |

#### 诊断方法

```python
import numpy as np
from scipy.stats import chi2

def check_nis(innovation, S, confidence=0.95):
    """
    检查 NIS 是否在合理范围内
    
    参数:
        innovation: 新息向量 (m,)
        S: 新息协方差矩阵 (m, m)
        confidence: 置信水平
    
    返回:
        nis: NIS 值
        is_consistent: 是否一致
        threshold_low: 下界
        threshold_high: 上界
    """
    m = len(innovation)
    
    # 计算 NIS
    nis = innovation.T @ np.linalg.inv(S) @ innovation
    
    # 计算阈值
    alpha = 1 - confidence
    threshold_low = chi2.ppf(alpha/2, m)
    threshold_high = chi2.ppf(1 - alpha/2, m)
    
    # 判断是否一致
    is_consistent = threshold_low <= nis <= threshold_high
    
    return nis, is_consistent, threshold_low, threshold_high


def analyze_nis_sequence(nis_values, m, window_size=100):
    """
    分析 NIS 序列的统计特性
    
    参数:
        nis_values: NIS 序列
        m: 观测维度
        window_size: 滑动窗口大小
    """
    # 基本统计
    mean_nis = np.mean(nis_values)
    expected_mean = m  # 卡方分布的期望值
    
    print(f"NIS 统计:")
    print(f"  均值: {mean_nis:.3f} (期望: {expected_mean:.3f})")
    print(f"  标准差: {np.std(nis_values):.3f}")
    print(f"  最大值: {np.max(nis_values):.3f}")
    print(f"  最小值: {np.min(nis_values):.3f}")
    
    # 检查一致性比例
    threshold = chi2.ppf(0.975, m)
    consistent_ratio = np.mean(nis_values <= threshold)
    print(f"  一致比例: {consistent_ratio*100:.1f}%")
    
    # 滑动窗口分析
    if len(nis_values) >= window_size:
        window_means = np.convolve(nis_values, np.ones(window_size)/window_size, mode='valid')
        print(f"  滑动窗口均值 (size={window_size}):")
        print(f"    最小: {np.min(window_means):.3f}")
        print(f"    最大: {np.max(window_means):.3f}")
    
    # 诊断
    if mean_nis > expected_mean * 2:
        print("⚠️ NIS 均值过大，可能原因:")
        print("  - 观测噪声参数 R 设置过小")
        print("  - 过程噪声参数 Q 设置过小")
        print("  - 模型不准确（线性化误差大）")
        print("  - 存在外点")
    elif mean_nis < expected_mean * 0.5:
        print("⚠️ NIS 均值过小，可能原因:")
        print("  - 观测噪声参数 R 设置过大")
        print("  - 过程噪声参数 Q 设置过大")
        print("  - 滤波器过于保守")
    
    return mean_nis
```

#### 常见问题诊断

| NIS 特征 | 可能原因 | 解决方案 |
|---------|---------|---------|
| NIS 持续过大 | 噪声参数不准、模型错误、外点 | 调整 R/Q、检查模型、使用鲁棒方法 |
| NIS 持续过小 | 噪声参数过大、滤波器保守 | 减小 R/Q |
| NIS 突然跳变 | 动态物体、传感器故障 | 检测并剔除外点 |
| NIS 周期性波动 | 系统性误差、未建模动态 | 检查系统性误差源 |

---

### 10.2 NEES (Normalized Estimation Error Squared)

#### 理论基础

当有真值（ground truth）时，可以计算 NEES：

$$
\text{NEES}_k = (\hat{\mathbf{x}}_k - \mathbf{x}_k^{gt})^T \mathbf{P}_k^{-1} (\hat{\mathbf{x}}_k - \mathbf{x}_k^{gt})
$$

其中 $\mathbf{x}_k^{gt}$ 是真值。

#### 统计特性

如果滤波器一致，NEES 也应该服从卡方分布：

$$
\text{NEES}_k \sim \chi^2(n)
$$

其中 $n$ 是状态向量的维度。

#### 诊断方法

```python
def check_nees(state_estimate, state_truth, P, confidence=0.95):
    """
    检查 NEES
    
    参数:
        state_estimate: 状态估计 (n,)
        state_truth: 真值状态 (n,)
        P: 状态协方差矩阵 (n, n)
        confidence: 置信水平
    
    返回:
        nees: NEES 值
        is_consistent: 是否一致
    """
    n = len(state_estimate)
    
    # 计算误差
    error = state_estimate - state_truth
    
    # 计算 NEES
    nees = error.T @ np.linalg.inv(P) @ error
    
    # 计算阈值
    alpha = 1 - confidence
    threshold_low = chi2.ppf(alpha/2, n)
    threshold_high = chi2.ppf(1 - alpha/2, n)
    
    # 判断是否一致
    is_consistent = threshold_low <= nees <= threshold_high
    
    return nees, is_consistent, threshold_low, threshold_high


def analyze_nees_sequence(nees_values, n):
    """
    分析 NEES 序列
    
    参数:
        nees_values: NEES 序列
        n: 状态维度
    """
    mean_nees = np.mean(nees_values)
    expected_mean = n
    
    print(f"NEES 统计:")
    print(f"  均值: {mean_nees:.3f} (期望: {expected_mean:.3f})")
    print(f"  标准差: {np.std(nees_values):.3f}")
    
    # 按状态分量分析
    # 需要将 NEES 分解到各个状态分量
    # 这需要在计算 NEES 时记录每个分量的贡献
    
    # 诊断
    if mean_nees > expected_mean * 2:
        print("⚠️ NEES 均值过大，滤波器不一致（过于乐观）")
        print("  可能原因: 噪声参数过小、线性化误差大、FEJ 未正确使用")
    elif mean_nees < expected_mean * 0.5:
        print("⚠️ NEES 均值过小，滤波器不一致（过于保守）")
        print("  可能原因: 噪声参数过大、未充分利用观测信息")
    
    return mean_nees
```

#### NEES 与 NIS 的区别

| 指标 | 需要真值 | 检验对象 | 应用场景 |
|------|---------|---------|---------|
| NIS | 不需要 | 新息的一致性 | 在线诊断 |
| NEES | 需要 | 估计误差的一致性 | 离线评估 |

---

### 10.3 协方差矩阵分析

#### 10.3.1 协方差矩阵的性质

协方差矩阵 $\mathbf{P}$ 反映了状态估计的不确定性。

**重要性质**：
- 对称正定矩阵
- 对角线元素：各状态分量的方差
- 非对角线元素：状态分量之间的协方差
- 迹（trace）：总不确定性
- 行列式：不确定性体积
- 特征值：主方向上的不确定性

#### 10.3.2 协方差矩阵的诊断指标

```python
def analyze_covariance_matrix(P, state_names=None):
    """
    分析协方差矩阵的健康状况
    
    参数:
        P: 协方差矩阵 (n, n)
        state_names: 状态名称列表（可选）
    """
    n = P.shape[0]
    
    print("=" * 60)
    print("协方差矩阵分析")
    print("=" * 60)
    
    # 1. 检查正定性
    eigenvalues = np.linalg.eigvalsh(P)
    min_eigenvalue = np.min(eigenvalues)
    
    print(f"\n1. 正定性检查:")
    if min_eigenvalue <= 0:
        print(f"  ❌ 非正定！最小特征值: {min_eigenvalue:.2e}")
        print("  原因: 数值误差、边缘化错误、噪声参数不当")
    else:
        print(f"  ✅ 正定，最小特征值: {min_eigenvalue:.2e}")
    
    # 2. 条件数
    max_eigenvalue = np.max(eigenvalues)
    condition_number = max_eigenvalue / min_eigenvalue if min_eigenvalue > 0 else np.inf
    
    print(f"\n2. 条件数:")
    print(f"  条件数: {condition_number:.2e}")
    if condition_number > 1e6:
        print(f"  ⚠️ 条件数过大，矩阵病态")
        print("  影响: 卡尔曼增益计算不稳定")
        print("  解决: 添加正则化、检查边缘化实现")
    elif condition_number > 1e4:
        print(f"  ⚠️ 条件数较大，需要注意")
    else:
        print(f"  ✅ 条件数良好")
    
    # 3. 迹（总不确定性）
    trace_P = np.trace(P)
    print(f"\n3. 总不确定性 (迹):")
    print(f"  trace(P) = {trace_P:.3e}")
    
    # 4. 特征值分布
    print(f"\n4. 特征值分布:")
    sorted_eigenvalues = np.sort(eigenvalues)[::-1]
    print(f"  最大特征值: {sorted_eigenvalues[0]:.3e}")
    print(f"  最小特征值: {sorted_eigenvalues[-1]:.3e}")
    print(f"  中位数: {np.median(eigenvalues):.3e}")
    
    # 检查特征值分布是否合理
    ratio = sorted_eigenvalues[0] / sorted_eigenvalues[-1]
    if ratio > 1e6:
        print(f"  ⚠️ 特征值分布极不均匀，某些方向不确定性过大")
    
    # 5. 对角线元素（各状态分量的方差）
    print(f"\n5. 各状态分量的标准差:")
    std_devs = np.sqrt(np.diag(P))
    
    if state_names is None:
        state_names = [f"状态 {i}" for i in range(n)]
    
    for i, (name, std) in enumerate(zip(state_names, std_devs)):
        print(f"  {name}: {std:.3e}")
        
        # 诊断异常值
        if std > 1.0:  # 阈值根据具体问题调整
            print(f"    ⚠️ 标准差过大，估计不确定")
        elif std < 1e-6:
            print(f"    ⚠️ 标准差过小，可能过于自信")
    
    # 6. 非对角线元素（相关性）
    print(f"\n6. 状态相关性分析:")
    correlation_matrix = np.zeros((n, n))
    for i in range(n):
        for j in range(n):
            if i != j:
                correlation_matrix[i, j] = P[i, j] / (std_devs[i] * std_devs[j])
    
    # 找出强相关的状态对
    strong_correlations = []
    for i in range(n):
        for j in range(i+1, n):
            if abs(correlation_matrix[i, j]) > 0.8:
                strong_correlations.append((i, j, correlation_matrix[i, j]))
    
    if strong_correlations:
        print(f"  发现 {len(strong_correlations)} 对强相关状态:")
        for i, j, corr in strong_correlations:
            print(f"    {state_names[i]} <-> {state_names[j]}: {corr:.3f}")
        print("  ⚠️ 强相关可能导致数值不稳定")
    else:
        print(f"  ✅ 状态间相关性合理")
    
    print("=" * 60)
    
    return {
        'min_eigenvalue': min_eigenvalue,
        'max_eigenvalue': max_eigenvalue,
        'condition_number': condition_number,
        'trace': trace_P,
        'eigenvalues': eigenvalues,
        'std_devs': std_devs
    }
```

#### 10.3.3 协方差矩阵的演化分析

```python
def analyze_covariance_evolution(P_sequence, dt=0.1):
    """
    分析协方差矩阵随时间的演化
    
    参数:
        P_sequence: 协方差矩阵序列 [(n,n), (n,n), ...]
        dt: 时间步长
    """
    n_steps = len(P_sequence)
    n_states = P_sequence[0].shape[0]
    
    # 提取迹的序列
    trace_sequence = [np.trace(P) for P in P_sequence]
    
    # 提取对角线元素的序列
    diag_sequence = np.array([np.diag(P) for P in P_sequence])
    
    # 提取特征值的序列
    eigenvalue_sequence = np.array([np.linalg.eigvalsh(P) for P in P_sequence])
    
    print("协方差矩阵演化分析:")
    print(f"  时间步数: {n_steps}")
    print(f"  总时长: {n_steps * dt:.2f}s")
    
    # 分析迹的变化
    print(f"\n1. 总不确定性 (迹) 的变化:")
    print(f"  初始: {trace_sequence[0]:.3e}")
    print(f"  最终: {trace_sequence[-1]:.3e}")
    print(f"  变化: {(trace_sequence[-1] - trace_sequence[0]) / trace_sequence[0] * 100:.1f}%")
    
    # 检查是否持续增长
    if trace_sequence[-1] > trace_sequence[0] * 10:
        print("  ⚠️ 不确定性持续增长，可能原因:")
        print("    - 没有足够的观测更新")
        print("    - 过程噪声 Q 设置过大")
        print("    - 系统不可观测")
    
    # 分析各状态分量的不确定性
    print(f"\n2. 各状态分量的不确定性演化:")
    for i in range(n_states):
        initial_std = np.sqrt(diag_sequence[0, i])
        final_std = np.sqrt(diag_sequence[-1, i])
        change = (final_std - initial_std) / initial_std * 100
        
        print(f"  状态 {i}: {initial_std:.3e} -> {final_std:.3e} ({change:+.1f}%)")
        
        if final_std > initial_std * 5:
            print(f"    ⚠️ 不确定性显著增长，可能不可观测")
    
    # 分析特征值演化
    print(f"\n3. 特征值演化:")
    initial_eigenvalues = eigenvalue_sequence[0]
    final_eigenvalues = eigenvalue_sequence[-1]
    
    print(f"  最小特征值: {initial_eigenvalues[0]:.3e} -> {final_eigenvalues[0]:.3e}")
    print(f"  最大特征值: {initial_eigenvalues[-1]:.3e} -> {final_eigenvalues[-1]:.3e}")
    
    # 检查是否有特征值趋向零
    if np.min(final_eigenvalues) < 1e-10:
        print("  ⚠️ 有特征值趋向零，协方差矩阵可能退化")
    
    return trace_sequence, diag_sequence, eigenvalue_sequence
```

---

### 10.4 可观测性分析

#### 10.4.1 可观测性矩阵

对于线性系统 $\mathbf{x}_{k+1} = \mathbf{F}_k \mathbf{x}_k + \mathbf{w}_k$，$\mathbf{z}_k = \mathbf{H}_k \mathbf{x}_k + \mathbf{v}_k$，可观测性矩阵定义为：

$$
\mathcal{O}_k = \begin{bmatrix}
\mathbf{H}_k \\
\mathbf{H}_{k+1} \mathbf{F}_k \\
\mathbf{H}_{k+2} \mathbf{F}_{k+1} \mathbf{F}_k \\
\vdots \\
\mathbf{H}_{k+N-1} \prod_{i=0}^{N-2} \mathbf{F}_{k+i}
\end{bmatrix}
$$

**可观测性判据**：系统可观测当且仅当 $\text{rank}(\mathcal{O}_k) = n$。

#### 10.4.2 可观测性 Gramian

可观测性 Gramian 矩阵：

$$
\mathbf{W}_o(k, k+N) = \sum_{i=k}^{k+N-1} \left( \prod_{j=k}^{i-1} \mathbf{F}_j \right)^T \mathbf{H}_i^T \mathbf{H}_i \left( \prod_{j=k}^{i-1} \mathbf{F}_j \right)
$$

**性质**：
- $\mathbf{W}_o$ 正定 $\iff$ 系统可观测
- $\mathbf{W}_o$ 的特征值反映各方向的可观测程度
- $\text{trace}(\mathbf{W}_o)$ 反映总的可观测性

#### 10.4.3 可观测性诊断

```python
def analyze_observability(F_sequence, H_sequence, window_size=10):
    """
    分析系统的可观测性
    
    参数:
        F_sequence: 状态转移矩阵序列
        H_sequence: 观测矩阵序列
        window_size: 分析窗口大小
    
    返回:
        observability_metrics: 可观测性指标
    """
    n_steps = len(F_sequence)
    n_states = F_sequence[0].shape[0]
    
    print("=" * 60)
    print("可观测性分析")
    print("=" * 60)
    
    if n_steps < window_size:
        print(f"⚠️ 数据不足，需要至少 {window_size} 步")
        return None
    
    # 构建可观测性矩阵
    O_blocks = []
    
    for k in range(n_steps - window_size + 1):
        O_k = H_sequence[k]
        F_prod = np.eye(n_states)
        
        for i in range(1, window_size):
            F_prod = F_sequence[k + i - 1] @ F_prod
            O_k = np.vstack([O_k, H_sequence[k + i] @ F_prod])
        
        O_blocks.append(O_k)
    
    # 分析可观测性矩阵
    print(f"\n1. 可观测性矩阵分析 (窗口大小: {window_size}):")
    
    ranks = []
    for k, O_k in enumerate(O_blocks):
        rank = np.linalg.matrix_rank(O_k, tol=1e-6)
        ranks.append(rank)
        
        if rank < n_states:
            print(f"  时刻 {k}: rank = {rank}/{n_states} ⚠️ 不可观测")
        else:
            print(f"  时刻 {k}: rank = {rank}/{n_states} ✅")
    
    # 统计可观测性
    observable_ratio = np.mean([r == n_states for r in ranks])
    print(f"\n2. 可观测性统计:")
    print(f"  可观测比例: {observable_ratio*100:.1f}%")
    
    if observable_ratio < 0.5:
        print("  ⚠️ 系统大部分时间不可观测")
        print("  可能原因:")
        print("    - 运动激励不足（退化运动）")
        print("    - 观测信息不足")
        print("    - 系统本身存在不可观测量")
    
    # 分析可观测性 Gramian
    print(f"\n3. 可观测性 Gramian 分析:")
    
    gramian_eigenvalues = []
    for k, O_k in enumerate(O_blocks[:5]):  # 只分析前5个窗口
        W_o = O_k.T @ O_k
        eigenvalues = np.linalg.eigvalsh(W_o)
        gramian_eigenvalues.append(eigenvalues)
        
        min_eig = np.min(eigenvalues)
        max_eig = np.max(eigenvalues)
        condition = max_eig / min_eig if min_eig > 0 else np.inf
        
        print(f"  窗口 {k}:")
        print(f"    最小特征值: {min_eig:.3e}")
        print(f"    最大特征值: {max_eig:.3e}")
        print(f"    条件数: {condition:.3e}")
        
        if min_eig < 1e-6:
            print(f"    ⚠️ 可观测性差，某些方向几乎不可观测")
    
    # 识别不可观测的方向
    print(f"\n4. 不可观测方向分析:")
    
    if len(O_blocks) > 0:
        # 使用 SVD 分析
        U, S, Vh = np.linalg.svd(O_blocks[0], full_matrices=False)
        
        # 找出小的奇异值对应的方向
        threshold = 1e-6
        unobservable_directions = Vh[S < threshold]
        
        if len(unobservable_directions) > 0:
            print(f"  发现 {len(unobservable_directions)} 个不可观测方向:")
            for i, direction in enumerate(unobservable_directions):
                print(f"    方向 {i}: {direction}")
                # 找出最大的分量
                max_idx = np.argmax(np.abs(direction))
                print(f"      主要影响状态: {max_idx}")
        else:
            print(f"  ✅ 所有方向都可观测")
    
    print("=" * 60)
    
    return {
        'ranks': ranks,
        'observable_ratio': observable_ratio,
        'gramian_eigenvalues': gramian_eigenvalues
    }
```

#### 10.4.4 VIO 系统中的可观测性

**VIO 系统的可观测性分析**：

| 状态分量 | 可观测性条件 | 说明 |
|---------|------------|------|
| 位置 $\mathbf{p}$ | 需要平移运动 | 静止时不可观测 |
| 速度 $\mathbf{v}$ | 需要加速度激励 | 匀速运动时不可观测 |
| 旋转 $\mathbf{R}$ | 需要旋转运动 | 纯平移时部分不可观测 |
| 陀螺仪 bias $\mathbf{b}_g$ | 需要旋转运动 | 静止时不可观测 |
| 加速度计 bias $\mathbf{b}_a$ | 需要平移运动 + 重力 | 静止时只观测到重力方向 |
| Landmark 深度 | 需要视差 | 纯旋转时不可观测 |

**退化运动**：

| 运动类型 | 不可观测的状态 | 原因 |
|---------|--------------|------|
| 静止 | 位置、速度、$\mathbf{b}_g$ | 无运动激励 |
| 匀速直线 | $\mathbf{b}_a$（垂直于运动方向） | 无加速度激励 |
| 纯旋转 | 位置、速度、landmark 深度 | 无视差 |
| 平面运动 | 垂直于平面的状态 | 运动受限 |

---

### 10.5 卡尔曼增益分析

#### 10.5.1 卡尔曼增益的物理意义

$$
\mathbf{K}_k = \mathbf{P}_{k|k-1} \mathbf{H}_k^T (\mathbf{H}_k \mathbf{P}_{k|k-1} \mathbf{H}_k^T + \mathbf{R}_k)^{-1}
$$

**卡尔曼增益的特性**：
- $\mathbf{K} \to 0$：更相信预测（观测噪声大）
- $\mathbf{K} \to \mathbf{P}\mathbf{H}^T\mathbf{R}^{-1}$：更相信观测（预测噪声大）
- $\|\mathbf{K}\|$ 反映更新强度

#### 10.5.2 卡尔曼增益诊断

```python
def analyze_kalman_gain(K, P, H, R, state_names=None):
    """
    分析卡尔曼增益
    
    参数:
        K: 卡尔曼增益矩阵 (n, m)
        P: 预测协方差 (n, n)
        H: 观测矩阵 (m, n)
        R: 观测噪声协方差 (m, m)
        state_names: 状态名称列表
    """
    n, m = K.shape
    
    print("=" * 60)
    print("卡尔曼增益分析")
    print("=" * 60)
    
    # 1. 增益的范数
    K_norm = np.linalg.norm(K, ord=2)
    print(f"\n1. 增益范数:")
    print(f"  ||K||_2 = {K_norm:.3e}")
    
    if K_norm > 1.0:
        print(f"  ⚠️ 增益过大，可能原因:")
        print(f"    - 观测噪声 R 设置过小")
        print(f"    - 预测协方差 P 设置过大")
        print(f"    - 系统过于相信观测")
    elif K_norm < 1e-3:
        print(f"  ⚠️ 增益过小，可能原因:")
        print(f"    - 观测噪声 R 设置过大")
        print(f"    - 预测协方差 P 设置过小")
        print(f"    - 系统过于相信预测")
    
    # 2. 各状态的增益
    print(f"\n2. 各状态的增益:")
    if state_names is None:
        state_names = [f"状态 {i}" for i in range(n)]
    
    K_row_norms = np.linalg.norm(K, axis=1)
    for i, (name, norm) in enumerate(zip(state_names, K_row_norms)):
        print(f"  {name}: {norm:.3e}")
        
        if norm > 1.0:
            print(f"    ⚠️ 该状态过度依赖观测")
        elif norm < 1e-4:
            print(f"    ⚠️ 该状态几乎不更新")
    
    # 3. 增益的分布
    print(f"\n3. 增益分布:")
    print(f"  最大值: {np.max(np.abs(K)):.3e}")
    print(f"  最小值: {np.min(np.abs(K)):.3e}")
    print(f"  平均值: {np.mean(np.abs(K)):.3e}")
    
    # 4. 检查增益的合理性
    # 理论上 K 应该满足: K = P H^T S^{-1}
    S = H @ P @ H.T + R
    K_expected = P @ H.T @ np.linalg.inv(S)
    K_error = np.linalg.norm(K - K_expected)
    
    print(f"\n4. 增益计算验证:")
    print(f"  ||K - K_expected|| = {K_error:.3e}")
    
    if K_error > 1e-6:
        print(f"  ⚠️ 增益计算有误，检查实现")
    else:
        print(f"  ✅ 增益计算正确")
    
    print("=" * 60)
    
    return {
        'K_norm': K_norm,
        'K_row_norms': K_row_norms,
        'K_error': K_error
    }
```

#### 10.5.3 增益异常的诊断

| 增益特征 | 可能原因 | 解决方案 |
|---------|---------|---------|
| 增益过大 | R 过小、P 过大 | 调整 R/Q、检查协方差传播 |
| 增益过小 | R 过大、P 过小 | 调整 R/Q、检查协方差传播 |
| 增益剧烈波动 | 观测质量不稳定 | 使用自适应滤波、检测外点 |
| 某些状态增益为零 | 不可观测 | 检查可观测性、改进运动激励 |
| 增益矩阵奇异 | 数值问题 | 使用正则化、改进数值稳定性 |

---

### 10.6 滤波器一致性检验

#### 10.6.1 一致性检验方法

**方法 1：NIS/NEES 检验**（见 10.1 和 10.2 节）

**方法 2：自相关检验**

检查新息序列是否白噪声：

```python
def check_innovation_whiteness(innovation_sequence, max_lag=10):
    """
    检查新息序列是否为白噪声
    
    参数:
        innovation_sequence: 新息序列 [(m,), (m,), ...]
        max_lag: 最大滞后阶数
    """
    innovations = np.array(innovation_sequence)
    n_steps, m = innovations.shape
    
    print("=" * 60)
    print("新息白噪声检验")
    print("=" * 60)
    
    # 计算自相关函数
    autocorrelations = []
    
    for lag in range(max_lag + 1):
        if lag == 0:
            # 零滞后：方差
            ac = np.mean(innovations**2, axis=0)
        else:
            # 非零滞后：自相关
            ac = np.mean(innovations[lag:] * innovations[:-lag], axis=0)
        
        autocorrelations.append(ac)
    
    autocorrelations = np.array(autocorrelations)
    
    # 分析结果
    print(f"\n1. 自相关分析:")
    for lag in range(max_lag + 1):
        ac_norm = np.linalg.norm(autocorrelations[lag])
        print(f"  滞后 {lag}: {ac_norm:.3e}")
        
        if lag > 0 and ac_norm > 0.1 * np.linalg.norm(autocorrelations[0]):
            print(f"    ⚠️ 存在显著自相关，滤波器可能不一致")
    
    # Ljung-Box 检验
    print(f"\n2. Ljung-Box 检验:")
    for i in range(m):
        Q = n_steps * (n_steps + 2) * sum(
            autocorrelations[lag, i]**2 / (n_steps - lag)
            for lag in range(1, max_lag + 1)
        )
        
        # 临界值（chi-squared 分布）
        critical_value = chi2.ppf(0.95, max_lag)
        
        print(f"  观测 {i}: Q = {Q:.3f}, 临界值 = {critical_value:.3f}")
        
        if Q > critical_value:
            print(f"    ⚠️ 拒绝白噪声假设")
        else:
            print(f"    ✅ 符合白噪声假设")
    
    print("=" * 60)
```

#### 10.6.2 一致性问题的诊断

| 不一致类型 | 表现 | 原因 | 解决方案 |
|-----------|------|------|---------|
| 过于乐观 | NIS/NEES 过大 | 噪声参数过小、线性化误差 | 增大 R/Q、使用 FEJ |
| 过于保守 | NIS/NEES 过小 | 噪声参数过大 | 减小 R/Q |
| 时间相关 | 自相关显著 | 未建模动态、系统性误差 | 改进模型、检查误差源 |
| 空间相关 | 不同观测相关 | 观测噪声相关 | 使用非对角 R |

---

### 10.7 滤波器稳定性监控

#### 10.7.1 发散检测

```python
def detect_divergence(state_sequence, P_sequence, threshold=10.0):
    """
    检测滤波器是否发散
    
    参数:
        state_sequence: 状态估计序列
        P_sequence: 协方差序列
        threshold: 发散阈值
    """
    n_steps = len(state_sequence)
    n_states = state_sequence[0].shape[0]
    
    print("=" * 60)
    print("滤波器稳定性监控")
    print("=" * 60)
    
    # 1. 检查状态跳变
    print(f"\n1. 状态跳变检测:")
    max_jumps = []
    
    for i in range(1, n_steps):
        delta = state_sequence[i] - state_sequence[i-1]
        delta_norm = np.linalg.norm(delta)
        max_jumps.append(delta_norm)
        
        if delta_norm > threshold:
            print(f"  时刻 {i}: 跳变 {delta_norm:.3e} ⚠️")
            print(f"    状态变化: {delta}")
    
    if max_jumps:
        avg_jump = np.mean(max_jumps)
        print(f"  平均跳变: {avg_jump:.3e}")
        
        if avg_jump > threshold * 0.5:
            print(f"  ⚠️ 状态跳变过大，滤波器可能不稳定")
    
    # 2. 检查协方差增长
    print(f"\n2. 协方差增长检测:")
    
    trace_sequence = [np.trace(P) for P in P_sequence]
    trace_growth = trace_sequence[-1] / trace_sequence[0]
    
    print(f"  初始 trace(P): {trace_sequence[0]:.3e}")
    print(f"  最终 trace(P): {trace_sequence[-1]:.3e}")
    print(f"  增长倍数: {trace_growth:.2f}x")
    
    if trace_growth > 100:
        print(f"  ⚠️ 协方差增长过快，可能原因:")
        print(f"    - 过程噪声 Q 设置过大")
        print(f"    - 没有足够的观测更新")
        print(f"    - 系统不可观测")
    
    # 3. 检查协方差正定性
    print(f"\n3. 协方差正定性检测:")
    
    min_eigenvalues = []
    for i, P in enumerate(P_sequence):
        eigenvalues = np.linalg.eigvalsh(P)
        min_eig = np.min(eigenvalues)
        min_eigenvalues.append(min_eig)
        
        if min_eig <= 0:
            print(f"  时刻 {i}: 非正定 ⚠️")
            print(f"    最小特征值: {min_eig:.3e}")
    
    non_psd_ratio = np.mean([e <= 0 for e in min_eigenvalues])
    if non_psd_ratio > 0.01:
        print(f"  ⚠️ {non_psd_ratio*100:.1f}% 的时间协方差非正定")
    
    # 4. 综合诊断
    print(f"\n4. 综合诊断:")
    
    issues = []
    if max_jumps and np.mean(max_jumps) > threshold * 0.5:
        issues.append("状态跳变过大")
    if trace_growth > 100:
        issues.append("协方差增长过快")
    if non_psd_ratio > 0.01:
        issues.append("协方差经常非正定")
    
    if issues:
        print(f"  发现 {len(issues)} 个问题:")
        for issue in issues:
            print(f"    - {issue}")
        print(f"\n  建议:")
        print(f"    - 检查噪声参数设置")
        print(f"    - 检查模型正确性")
        print(f"    - 增加观测频率")
        print(f"    - 使用更稳定的数值方法")
    else:
        print(f"  ✅ 滤波器运行稳定")
    
    print("=" * 60)
    
    return {
        'max_jumps': max_jumps,
        'trace_growth': trace_growth,
        'non_psd_ratio': non_psd_ratio
    }
```

#### 10.7.2 稳定性指标汇总

| 指标 | 正常范围 | 异常阈值 | 异常原因 |
|------|---------|---------|---------|
| 状态跳变 | < 0.1 | > 1.0 | 模型错误、外点、噪声参数不当 |
| 协方差增长 | < 10x | > 100x | Q 过大、无观测、不可观测 |
| 正定性 | 100% | < 99% | 数值误差、边缘化错误 |
| NIS 均值 | ≈ m | > 2m 或 < 0.5m | 噪声参数不当、模型错误 |
| 自相关 | ≈ 0 | > 0.1 | 未建模动态、系统性误差 |

---

## 总结

滤波方法的诊断指标体系：

1. **NIS/NEES**：检验滤波器一致性（类似优化中的残差分析）
2. **协方差矩阵分析**：检验不确定性估计（类似优化中的 Hessian 分析）
3. **可观测性分析**：检验系统是否可观测（类似优化中的条件数分析）
4. **卡尔曼增益分析**：检验更新强度（类似优化中的步长分析）
5. **一致性检验**：检验滤波器统计特性
6. **稳定性监控**：检验滤波器是否发散

这些指标相互补充，共同构成完整的滤波诊断体系。在实际应用中，应该：

1. **在线监控**：实时监控 NIS、协方差、增益等指标
2. **离线分析**：使用 NEES、自相关等需要真值的指标
3. **定期诊断**：检查可观测性、一致性
4. **异常检测**：及时发现发散、不一致等问题

---

*本节持续更新，欢迎补充新的诊断指标和方法。*

### 关键知识点

1. **卡尔曼滤波**：预测-更新框架，最优线性估计
2. **EKF**：处理非线性系统，需要雅可比矩阵
3. **误差状态 EKF**：对误差状态滤波，数值稳定性好
4. **IMU 预积分**：避免重复积分，便于 bias 更新
5. **MSCKF**：多状态约束，固定状态维度，计算效率高
6. **FEJ**：使用首次估计的雅可比，保证一致性
7. **边缘化**：Schur 补，控制状态维度

### 滤波 vs 优化

| 特性 | 滤波 (MSCKF) | 优化 (VINS) |
|------|-------------|------------|
| 状态维度 | 固定 | 增长（需边缘化） |
| 计算效率 | 高 | 低 |
| 精度 | 中等 | 高 |
| 回环检测 | 不支持 | 支持 |
| 一致性 | 需要 FEJ | 天然一致 |
| 内存占用 | 小 | 大 |

### 选择建议

- **实时嵌入式系统**：MSCKF（OpenVINS）
- **高精度离线处理**：优化方法（VINS-Mono）
- **长时间运行**：滑动窗口优化
- **资源受限**：MSCKF

---

*本文档持续更新，欢迎补充新的理论和实践经验。*
