# Phase 0: 资料收集与整理

## 目标

收集目标代码库对应的所有相关资料：论文、文档、第三方解读，整理归档，为后续精读阶段提供原始素材。

## 触发词

- "收集资料"
- "找论文"
- "整理文档"

## 依赖

无（可作为第一个执行的 Phase）

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| repo_path | string | ✅ | 仓库根目录绝对路径 |

## 输出产物

```
{仓库名}-code-analysis/
├── docs/                              # 资料实体
│   ├── papers/
│   │   ├── main-paper.pdf             # 主论文 PDF
│   │   └── related/                   # 关联论文
│   ├── docs-online/                   # 在线文档缓存 (MD)
│   └── third-party/                   # 第三方解读 (MD)
│
└── 00_资料清单.md                     # 索引文件
```

## 执行步骤

### Step 1: 扫描代码内置线索

在 `repo_path` 中搜索以下内容：

**1.1 README 文件**
- 读取 `README.md`, `README_CN.md`, `readme.txt`
- 提取论文引用、官方文档链接、项目介绍中的关键词

**1.2 源码注释中的引用**
搜索以下模式：
```bash
# Grep 搜索模式
@see @cite reference "paper" "citation" // Reference: // Paper:
"IEEE" "TRO" "RAL" "ICRA" "IROS" "CVPR" "ECCV" "arXiv"
```
记录每个匹配的文件名、行号、引用内容。

**1.3 已有文档目录**
检查是否存在：
- `docs/`, `doc/`, `document/`
- `paper/`, `papers/`
- `wiki/`

如果存在，遍历并记录已有文件。

### Step 2: 自动搜索可获取的资料

**2.1 确定主论文**
根据以下信息推断主论文：
- 仓库名称（如 VINS-Mono → Qin et al. RAL 2018）
- README 中的声明
- 代码注释中的引用

**2.2 搜索关联论文**
根据代码模块推断可能涉及的关联论文：
- 有预积分 → Forster et al. TRO 2017 (On-Manifold Preintegration)
- 有边缘化 → 相关 marginalization 论文
- 有回环检测 → DBoW2 / 词袋模型相关论文
- 有初始化 → SfM / IMU 初始化相关论文

**2.3 搜索在线文档**
- GitHub Wiki（如果有）
- 官方网站文档页
- YouTube / Bilibili 讲解视频（记录链接）

**2.4 搜索第三方解读**
- 技术博客（CSDN, 知乎, 个人博客）
- GitHub Discussions / Issues 中的高质量讨论
- 学术笔记 / 课程讲义

### Step 3: 归档与下载

**3.0 文件命名规范（强制）**

所有下载、缓存的文件 **必须** 按以下规范统一命名，禁止使用原始文件名（如 `2103.07986.pdf`、`paper (1).pdf`）。

| 文件类型 | 命名格式 | 示例 |
|---------|---------|------|
| 主论文 | `main-paper.pdf` | `main-paper.pdf` |
| 关联论文 | `{Year}_{Venue}_{FirstAuthor}_{ShortTitle}.pdf` | `2017_TRO_Forster_On-Manifold-Preintegration.pdf` |
| 在线文档 | `{source}_{topic}.md` | `github-wiki_installation.md` |
| 第三方解读 | `{platform}_{author}_{topic}.md` | `zhihu_张三_VINS-Mono解析.md` |

字段规则：

1. **Year** — 论文正式发表年（非 arXiv 预发布年），四位数字
2. **Venue** — 会议/期刊缩写：`ICRA` `IROS` `RAL` `TRO` `CVPR` `ECCV` `ICCV` 等；纯 arXiv 论文用 `arXiv`
3. **FirstAuthor** — 第一作者姓，保留原拼写（英文原样，中文用拼音首字母大写）
4. **ShortTitle** — 论文核心关键词，用连字符 `-` 连接，不超过 3 个词
5. **字段分隔符** — 下划线 `_`；词内分隔符 — 连字符 `-`
6. **禁止** — 空格、特殊字符（`/ \ : * ? " < > |`）、中文标点

示例目录结构：

```
docs/
├── papers/
│   ├── main-paper.pdf
│   └── related/
│       ├── 2017_TRO_Forster_On-Manifold-Preintegration.pdf
│       ├── 2018_RAL_Qin_VINS-Mono.pdf
│       └── 2020_arXiv_Rosinol_Kimera.pdf
├── docs-online/
│   ├── github-wiki_installation.md
│   └── official-doc_config-params.md
└── third-party/
    ├── zhihu_张三_VINS-Mono解析.md
    └── csdn_李四_VIO预积分推导.md
```

**3.1 可直接获取的内容**
- 在线文档 → 按 3.0 命名规范缓存为 `.md` 存入 `docs/docs-online/`
- 开放获取的论文 PDF → 按 3.0 命名规范下载存入 `docs/papers/` 或 `docs/papers/related/`

**3.2 需要用户补充的内容**
生成缺失清单，明确告知：
- 缺什么论文/文档
- 为什么需要（对应哪个代码模块）
- 建议从哪里获取（arXiv, IEEE, 官网等）
- 放入后应使用的规范文件名

### Step 4: 生成 00_资料清单.md

套用 `templates/resource-list-template.md` 格式，包含以下章节：

```markdown
# 00_资料清单

> 仓库: {仓库名} | 生成日期: {日期}

## A. 主论文（核心，必读）

| # | 论文 | 作者/来源 | 年份/会议 | 位置 | 状态 |
|---|------|----------|---------|------|------|
| 1 | {论文名} | {作者} | {年份} | docs/papers/main-paper.pdf | ✅/🔗/❌ |

## B. 关联论文（按需读）

| # | 论文 | 对应代码模块 | 位置 | 状态 |
|---|------|------------|------|------|

## C. 在线文档

| # | 名称 | URL | 缓存位置 | 状态 |

## D. 第三方解读

| # | 来源 | 链接/位置 | 质量 | 备注 |

## E. 待补充项

- [ ] {缺失项} → 建议: {获取方式}
```

### Step 5: 与用户交互

如果有 **P0 级别的关键资料缺失**（如主论文），必须主动告知用户：

```
📋 Phase 0 完成 — 资料收集报告

✅ 已收集:
  - 主论文: {论文名} (已下载)
  - 在线文档: N 份 (已缓存)
  - 第三方解读: N 份

⚠️ 缺失的关键资料:
  1. {论文名} — 对应模块: {模块名}
     建议: 从 {URL} 下载后放入 docs/papers/related/

请将缺失资料放入指定目录后，告诉我继续。
```

如果所有关键资料齐全，可直接询问是否进入下一 Phase。

## 注意事项

1. **不要猜测论文**：如果不能确定某篇论文是否真的被该代码库使用，标注为"疑似"，不要当作事实写入
2. **尊重版权**：仅下载开放获取的论文；付费论文只提供链接和引用信息
3. **中文优先**：如果同时存在中文和英文解读，两者都收录但中文排前面
4. **版本匹配**：注意论文版本与代码版本的对应关系（代码可能基于论文的某个早期版本或改进版）
5. **文件命名**：所有下载文件必须遵守 Step 3.0 的命名规范，不得使用原始下载文件名
