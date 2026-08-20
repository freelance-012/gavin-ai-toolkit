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

## 总结

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
