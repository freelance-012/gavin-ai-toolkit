# SLAM 常用公式速查

> 收集 SLAM/VIO 领域最常用的数学公式，供代码阅读和论文理解时快速查阅。
> 所有公式使用统一符号约定。

---

## 符号约定

| 符号 | 含义 | 维度 |
|------|------|------|
| **R** / **q** | 旋转矩阵 / 四元数 | 3×3 / 4 |
| **p** | 位置向量 | 3×1 |
| **v** | 速度向量 | 3×1 |
| **bₐ**, **b_g** | 加速度计/陀螺仪 bias | 3×1 |
| **T** = [R \| p] | 位姿 (SE3) | 4×4 |
| **π(·)** | 3D→2D 投影函数 | 2×1 |
| **⊗** | 四元数乘法 | - |

坐标系下标: w=世界, b=机体/IMU, c=相机, i/j=帧索引

---

## 1. IMU 运动学 (连续时间)

### 1.1 状态传播方程

$$
\dot{\mathbf{p}}_w^b(t) = \mathbf{v}_w^b(t)
$$

$$
\dot{\mathbf{v}}_w^b(t) = \mathbf{R}_w^b(t) (\tilde{\mathbf{a}}_m(t) - \mathbf{b}_a - \mathbf{n}_a) + \mathbf{g}^w
$$

$$
\dot{\mathbf{R}}_w^b(t) = \mathbf{R}_w^b(t) [\tilde{\boldsymbol{\omega}}_m(t) - \mathbf{b}_g - \mathbf{n}_g]_\times
$$

其中:
- $\tilde{\mathbf{a}}_m$, $\tilde{\boldsymbol{\omega}}_m$: IMU 测量值
- $\mathbf{n}_a$, $\mathbf{n}_g$: 高斯白噪声
- $[\cdot]_\times$: 反对称矩阵（叉积算子）
- $\mathbf{g}^w$: 重力向量（世界系）

---

## 2. IMU 预积分 (Preintegration)

### 2.1 预积分量定义 (Forster TRO 2017)

在时间区间 $[t_i, t_j]$ 上，消除 bias 后的预积分量：

$$
\hat{\boldsymbol{\alpha}}_{ij} = \int_{t_i}^{t_j} \int_{t_i}^{s} \hat{\mathbf{R}}_{is} (\tilde{\mathbf{a}}_s - \hat{\mathbf{b}}_{a_i}) \, ds \, dt
$$

$$
\hat{\boldsymbol{\beta}}_{ij} = \int_{t_i}^{t_j} \hat{\mathbf{R}}_{is} (\tilde{\mathbf{a}}_s - \hat{\mathbf{b}}_{a_i}) \, ds
$$

$$
\hat{\boldsymbol{\gamma}}_{ij} = \int_{t_i}^{t_j} \frac{1}{2} \hat{\boldsymbol{\gamma}}_{is} \otimes [\tilde{\boldsymbol{\omega}}_s - \hat{\mathbf{b}}_{g_i}]_\times \, dt
$$

对应代码变量: `delta_p_`, `delta_v_`, `delta_q_`

### 2.2 Bias 更新的一阶近似 (雅可比)

当 bias 从 $\hat{\mathbf{b}}$ 变为 $\tilde{\mathbf{b}} = \hat{\mathbf{b}} + \delta\mathbf{b}$ 时：

$$
\tilde{\boldsymbol{\alpha}}_{ij} \approx \hat{\boldsymbol{\alpha}}_{ij} + \mathbf{J}_{b_a}^{\alpha} \delta\mathbf{b}_{a} + \mathbf{J}_{b_g}^{\alpha} \delta\mathbf{b}_{g}
$$

其中 $\mathbf{J}_{b_a}^{\alpha}$ 和 $\mathbf{J}_{b_g}^{\alpha}$ 为预积分量对 bias 的雅可比。

对应代码变量: `jac_a_` ($\partial\Delta/\partial b_a$), `jac_g_` ($\partial\Delta/\partial b_g$)

### 2.3 协方差传播

$$
\mathbf{P}_{ij} = \mathbf{A}_{k-1} \mathbf{P}_{k-1} \mathbf{A}_{k-1}^T + \mathbf{Q}_k
$$

其中:
- $\mathbf{A}$: 状态转移矩阵的雅可比
- $\mathbf{Q}$: 噪声协方差矩阵 (15×15)

---

## 3. 视觉观测模型

### 3.1 针孔相机投影

$$
\mathbf{z} = \pi(\mathbf{x}) = \begin{bmatrix} f_x \frac{X}{Z} + c_x \\ f_y \frac{Y}{Z} + c_y \end{bmatrix}
$$

其中 $\mathbf{x} = [X, Y, Z]^T$ 是相机坐标系下的 3D 点。

### 3.2 重投影误差 (视觉残差)

$$
\mathbf{r}_V = \mathbf{z}_{obs} - \pi(\mathbf{R}_{cw} (\mathbf{R}_{wb}^T (\mathbf{p}_w^f - \mathbf{p}_w^b) - \mathbf{p}_c^b))
$$

或等价地：
$$
\mathbf{r}_V = \mathbf{z}_{obs} - \pi(\mathbf{T}_{cb}^{-1} \mathbf{T}_{bw}^{-1} \mathbf{p}_w^f)
$$

### 3.3 归一化平面误差 (某些实现使用)

$$
\mathbf{r}_V' = \frac{\mathbf{x}_{obs}}{\|\mathbf{x}_{obs}\|} - \frac{\mathbf{x}_{pred}}{\|\mathbf{x}_{pred}\|}
$$

---

## 4. IMU 残差 (预积分残差)

### 4.1 残差定义 (VINS 论文 Eq.67)

$$
\mathbf{r}_{\mathcal{I}} = \begin{bmatrix}
\mathbf{r}_p \\ \mathbf{r}_v \\ \mathbf{r}_q \\ \mathbf{r}_{ba} \\ \mathbf{r}_{bg}
\end{bmatrix}
= \begin{bmatrix}
\mathbf{R}_{wi}^T (\hat{\mathbf{p}}_{wj} - \mathbf{p}_{wi} - \mathbf{v}_i \Delta t_{ij} + \frac{1}{2}\mathbf{g}\Delta t_{ij}^2 - \mathbf{R}_{bi}^T \hat{\boldsymbol{\alpha}}_{ij}) \\
\mathbf{R}_{wi}^T (\hat{\mathbf{v}}_{wj} - \mathbf{v}_i + \mathbf{g}\Delta t_{ij} - \mathbf{R}_{bi}^T \hat{\boldsymbol{\beta}}_{ij}) \\
2[\gamma_{ij}^{-1} \otimes (\mathbf{R}_{bi}^T \mathbf{R}_{iw} \mathbf{R}_{wj} \mathbf{R}_{cj}^T)]_{xyz} \\
\mathbf{b}_{aj} - \mathbf{b}_{ai} \\
\mathbf{b}_{gj} - \mathbf{b}_{gi}
\end{bmatrix}
$$

残差维度: 15 (9 维运动 + 6 维 bias)

---

## 5. 边缘化 (Marginalization)

### 5.1 Schur 补公式

线性系统 $\begin{bmatrix} A & B \\ B^T & C \end{bmatrix} \begin{bmatrix} x \\ y \end{bmatrix} = \begin{bmatrix} u \\ v \end{bmatrix}$

消去 $y$ 后，$x$ 的先验信息:

$$
(A - B C^{-1} B^T) x = u - B C^{-1} v
$$

先验残差的协方差: $(A - B C^{-1} B^T)^{-1}$

### 5.2 FEJ (First Estimate Jacobian)

边缘化时使用**首次估计时的雅可比**而非当前估计的雅可比，避免"一致性过约"(over-commitment) 问题。

---

## 6. 四元数运算速查

### 6.1 基本运算

| 操作 | 公式 | 备注 |
|------|------|------|
| 乘法 | $\mathbf{q}_1 \otimes \mathbf{q}_2$ | Hamilton 积 |
| 共轭 | $\mathbf{q}^* = [w, -x, -y, -z]^T$ | 等价于逆（单位四元数） |
| 旋转矢量 → 四元数 | $\exp(\phi)$ | 小角度: $[1, \phi/2]^T$ |
| 四元数 → 旋转矢量 | $\log(\mathbf{q})$ | 小角度: $2 \cdot vec(q)$ |

### 6.2 BoxPlus / BoxMinus (李群运算)

$$
\mathbf{q} \boxplus \delta\mathbf{\phi} = \mathbf{q} \otimes \exp([\delta\mathbf{\phi}]_\times)
$$

$$
\mathbf{q}_1 \boxminus \mathbf{q}_2 = \log(\mathbf{q}_1^{-1} \otimes \mathbf{q}_2)
$$

---

## 7. 常用噪声模型

### 7.1 IMU 噪声参数

| 参数 | 符号 | 典型值 (消费级 IMU) | 单位 |
|------|------|-------------------|------|
| 加速度计噪声密度 | σₐ | 0.01 ~ 0.5 | m/s²/√Hz |
| 陀螺仪噪声密度 | σ_g | 0.0001 ~ 0.05 | rad/s/√Hz |
| 加速度计随机游走 | σ_{bₐ} | 1e-5 ~ 1e-3 | m/s³/√Hz |
| 陀螺仪随机游走 | σ_{bg} | 1e-6 ~ 1e-4 | rad/s²/√Hz |

### 7.2 视觉噪声

| 参数 | 典型值 | 说明 |
|------|--------|------|
| 像素标准差 | 0.5 ~ 2.0 pixel | 取决于特征提取质量 |
| 外点比例 | 10% ~ 30% | 取决于场景 |

---

*持续更新中。遇到新公式时随时补充。*
