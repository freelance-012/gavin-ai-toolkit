# Phase 2: 生成规格文件

## 目标

将 Phase 0 的自动扫描结果和 Phase 1 的用户确认信息汇总，生成结构化的 `project-spec.md` 文件。

## 触发词

- "生成 spec"
- "生成项目规格"
- "写入 spec"

## 依赖

Phase 0 的扫描结果 + Phase 1 的确认结果

## 输入参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_path | string | ✅ | 项目根目录绝对路径 |
| confirmed_info | object | ✅ | Phase 0 + Phase 1 汇总的已确认信息 |

## 输出产物

```
{project}/.specs/
└── project-spec.md
```

## 执行步骤

### Step 1: 创建目录

```bash
mkdir -p {project}/.specs
```

### Step 2: 套用模板生成 spec

读取 `templates/project-spec-template.md`，按模板格式填充所有信息。

**填充规则**：
- 已确认的项：直接填入
- 用户指定的项：填入，并在备注中标注"用户指定"
- 待确认的项：填入 AI 假设值，在备注中标注"⚠️ 待确认"
- 确实无法获取的项：填入"未知"，在备注中说明原因

### Step 3: 写入文件

将生成的 spec 内容写入 `{project}/.specs/project-spec.md`。

### Step 4: 展示结果

```markdown
✅ project-spec.md 已生成

📁 文件位置: {project}/.specs/project-spec.md
📊 统计:
  - 已确认: {N} 项
  - 用户指定: {N} 项
  - 待确认: {N} 项

待确认项将在 Phase 3 验证中标注。
是否继续执行 Phase 3 验证？(Y/n)
```

## 注意事项

1. **严格套用模板**：不要自行发明格式，必须使用 `project-spec-template.md` 中定义的章节和格式
2. **保留信息来源**：每个章节末尾可加注信息来源（代码/文档/用户）
3. **不丢失信息**：Phase 0 中低置信度的假设也要保留在 spec 中，标注"待确认"
4. **路径使用绝对路径**：spec 中所有路径使用绝对路径，避免歧义
