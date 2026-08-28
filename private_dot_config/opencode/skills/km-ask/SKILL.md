---
name: km-ask
version: "1.1.2"
description: |
  知识管理（KM）系统技能。当用户需要搜索知识、阅读文章或与 KM 系统交互时使用。支持 /km:search、/km:read 斜杠命令。所有操作通过 Bash 执行 popo-cli 命令完成。
domains:
  - documents
  - search
  - knowledge-base
---

# KM Skills

> KM 知识管理系统 Agent 技能 — 项目级入口与全局路由。

## CLI 参数规范

> ⚠️ **必须遵守**：每次执行 `popo-cli` 命令时，参数引号规则如下：

| 场景 | 规则 | 示例 |
|------|------|------|
| 简单值（无空格/特殊字符） | 不加引号 | `resourceType=blog` |
| 含空格或特殊字符的值 | 双引号包裹 | `query="SDD 架构设计"` |
| 数组/对象（macOS/Linux） | 双引号包裹，内部 `\"` 转义 | `ids="[\"id1\",\"id2\"]"` |
| 数组/对象（Windows） | 写入临时文件，`=@file:` 传递 | `ids=@file:/tmp/ids.json` |
| **禁止** | 使用单引号 | `query='关键词'` ❌ |

认证由 `popo-cli` 自动处理，无需手动配置。

## 严格规则

### 绝对禁止

- 不得捏造资源 ID — 必须从 API 返回结果中提取
- 不得在任何文件中硬编码 token、密码或 API Key
- 不得猜测参数值 — 必须查询确认后再使用
- 不得使用 `curl` 或编写脚本直接调用 KM API — 所有操作必须通过 `popo-cli` 命令

### 必须遵守

- 所有 KM API 调用必须通过 `popo-cli` 命令
- 破坏性操作（删除、更新）必须先向用户确认
- 资源 ID 必须在使用前验证（格式：字母数字、下划线、连字符，1-128 字符）
- 批量操作每次请求不得超过 100 条

## 产品域概览

| 域 | 描述 | popo-cli 命令 | 参考文档 |
|----|------|---------------|----------|
| 文档 | 按大纲和章节阅读文章（安全阅读） | `popo-cli km resource_outline`、`popo-cli km resource_section` | [references/products/documents.md](references/products/documents.md) |
| 搜索 | 全文搜索、高级查询、筛选 | `popo-cli km search_resource` | [search.md](references/products/search.md)（核心）、[search-reference.md](references/products/search-reference.md)（按需） |

> **注意**：产品域按需增量添加。所有 API 调用均使用上表中列出的 `popo-cli` 命令。

## 命令路由

当用户输入以 `/km:` 开头时，跳过意图分类，直接分发：

| 命令 | 域 | popo-cli 命令 | 参考文档 | 状态 |
|------|-----|---------------|----------|------|
| `/km:search <参数>` | 搜索 | `popo-cli km search_resource` | [search.md](references/products/search.md) | 已启用 |
| `/km:read <参数>` | 文档 | `popo-cli km resource_outline`、`popo-cli km resource_section` | [documents.md](references/products/documents.md) | 已启用 |

### 分发规则

1. 匹配命令前缀（`/km:search`、`/km:read`）
2. 提取 `<参数>` 为命令前缀之后的全部内容（去除首尾空白）
3. 若 `<参数>` 为空，提示用户输入域相关的信息
4. 若命令状态为 `已启用`，使用 `popo-cli` 命令调用对应工具并传入提取的参数
5. 若命令状态为 `已规划`，告知用户："该命令尚未开放。当前支持：/km:search、/km:read"
6. 若命令未知，回复："未知命令 `/km:<未知>`。可用命令：/km:search、/km:read"

### /km:search 分发

`/km:search <参数>` 将 `<参数>` 作为搜索输入：
- 应用搜索参数提取规则（见 [search.md](references/products/search.md)）
- 通过 `popo-cli km search_resource query="..." ...` 执行
- 按搜索结果格式化规则展示（见 [search.md](references/products/search.md)）
- 若 `<参数>` 为空：提示"请输入搜索内容，可以提供关键词、作者姓名、时间范围或资源类型。"

### /km:read 分发

`/km:read <参数>` 支持四种子命令：

| 子命令 | 描述 | 处理方式 |
|--------|------|----------|
| `/km:read <url>` | 通过 URL 获取文章大纲 | `popo-cli km resource_outline url=<url>` |
| `/km:read <类型> <ID>` | 通过类型+ID 获取文章大纲 | `popo-cli km resource_outline resourceType=<类型> resourceId=<ID>` |
| `/km:read section <n>` | 获取第 n 章内容 | `popo-cli km resource_section resourceType=... resourceId=... sectionIndex=<n>` |
| `/km:read full` | 获取全文（需确认） | `popo-cli km resource_section resourceType=... resourceId=... sectionIndex=-1` |

分发规则：
1. 若 `<参数>` 以 `http://` 或 `https://` 开头：提取 URL，执行 `popo-cli km resource_outline url=<url>`
2. 若 `<参数>` 为 `section <n>`：使用上次大纲调用上下文中的 `resourceType` 和 `resourceId`，执行 `popo-cli km resource_section resourceType={type} resourceId={id} sectionIndex=<n>`
3. 若 `<参数>` 为 `full`：先向用户确认（"全文内容将发送给 AI 进行分析，是否继续？"），然后执行 `popo-cli km resource_section resourceType={type} resourceId={id} sectionIndex=-1`
4. 若 `<参数>` 匹配 `<类型> <ID>`（类型为 `blog` 或 `page`）：执行 `popo-cli km resource_outline resourceType=<类型> resourceId=<ID>`
5. 若 `<参数>` 为空：提示"请提供 KM 文章 URL，或使用 `/km:read section <n>` 阅读特定章节。"
6. 对于 `section` 和 `full` 子命令：若无上次大纲上下文，告知用户："请先使用 `/km:read <url>` 打开文章获取目录。"

## 意图路由

当输入不以 `/km:` 开头时，使用意图分类：

### 决策树

```
用户输入
  │
  ▼
步骤 0: 检查斜杠命令
  │      以 /km: 开头  → 命令路由（见上文）
  │      否则          → 步骤 1
  │
  ▼
步骤 1: 分类意图（关注动词，而非名词）
  │      "搜索 / 查找 / 查询"  → 搜索域
  │      "阅读 / 查看 / 打开 / 浏览" + 文章/URL → 阅读域
  │      "分析 / 总结" + 章节/段落 → 阅读域
  │      模糊不清？  → 步骤 2
  │
  ▼
步骤 2: 处理歧义（绝不猜测 — 询问用户）
  │      域不明确？  → 询问用户澄清
  │      域已明确？  → 步骤 3
  │
  ▼
步骤 3: 映射到 API 端点
  │      加载相关产品参考文档获取 API 详情
  │
  ▼
步骤 4: 通过 popo-cli 执行
         使用对应域的 popo-cli 命令
```

### 意图映射

| 用户输入 | 真实意图 | 域 | 参考文档 |
|----------|----------|-----|----------|
| "查找关于X的文档" | 全文搜索 | 搜索 | [search.md](references/products/search.md) |
| "搜索X" | 全文搜索 | 搜索 | [search.md](references/products/search.md) |
| "阅读这篇文章 URL" | 文章大纲 | 阅读 | [documents.md](references/products/documents.md) |
| "打开文章 URL" | 文章大纲 | 阅读 | [documents.md](references/products/documents.md) |
| "看看这篇文章" | 文章大纲 | 阅读 | [documents.md](references/products/documents.md) |
| "分析第 2 章" | 章节阅读 | 阅读 | [documents.md](references/products/documents.md) |
| "读第 3 章" | 章节阅读 | 阅读 | [documents.md](references/products/documents.md) |
| "总结全文" | 全文阅读 | 阅读 | [documents.md](references/products/documents.md) |

### 搜索意图与执行

1. 分类意图 → 5 种类型（keyword_search、author_search、time_search、author_time_search、type_search）
2. 提取参数 → 关键词、作者、时间范围、资源类型
3. 执行 → `popo-cli km search_resource query="..." ...` 并传入提取的参数
4. 格式化结果 → 按展示约束中的六字段固定模板展示

核心规则：[references/products/search.md](references/products/search.md)

> **按需加载规则**：常规搜索仅加载 `search.md`。以下情况追加加载 [search-reference.md](references/products/search-reference.md)：
> - `popo-cli` 返回错误，需查看错误码表
> - 需要调试响应字段结构
> - 首次执行搜索，需参考工作流示例

### 阅读意图与执行

1. 分类意图 → 3 种类型（read_outline、read_section、read_full）
2. 提取参数 → URL、资源类型/ID、章节索引
3. 执行 → `popo-cli km resource_outline ...` 或 `popo-cli km resource_section ...`
4. 格式化结果 → 大纲表格、章节分析或全文（需确认）

完整规则：[references/products/documents.md](references/products/documents.md)

### 消歧表

| 用户输入 | 真实意图 | 域 | 不是 | 区分逻辑 |
|----------|----------|-----|------|----------|
| "查找关于AI的文档" | 全文搜索 | 搜索 | 文档 | 按内容关键词查询 → 搜索 |
| "查找我最近的文档" | 文档列表 | 文档 | 搜索 | 按归属/时间列出 → 文档 |
| "阅读这篇文章 URL" | 文章大纲 | 阅读 | 搜索 | 查看特定文章 → 阅读 |
| "看看文章 22594" | 文章大纲 | 阅读 | 搜索 | 按 ID 查看特定文章 → 阅读 |
| "分析第 2 章" | 章节阅读 | 阅读 | 文档 | 阅读章节内容 → 阅读 |
| "总结这篇文章" | 全文阅读 | 阅读 | 搜索 | 分析文章内容 → 阅读（需确认） |
| "搜索 SDD 文章" | keyword_search | 搜索 | — | 关键词搜索 via popo-cli km search_resource |
| "张三上个月的文章" | author_time_search | 搜索 | — | 作者+时间组合搜索 |
| "SDD 相关视频" | type_search | 搜索 | — | 类型筛选搜索 |

## 全局参考

| 参考文档 | 用途 | 路径 |
|----------|------|------|
| 全局参考 | 认证、输出格式、通用规则 | [references/global-reference.md](references/global-reference.md) |
| 错误码 | 跨域错误码与调试流程 | [references/error-codes.md](references/error-codes.md) |
| 意图指南 | 跨技能意图消歧规则 | [references/intent-guide.md](references/intent-guide.md) |
| 字段规则 | 全局字段类型、格式、校验 | [references/field-rules.md](references/field-rules.md) |
| 产品：文档 | 文章安全阅读 API 详情 | [references/products/documents.md](references/products/documents.md) |
| 产品：搜索 | 搜索 API 核心（请求参数、意图分类、展示约束） | [references/products/search.md](references/products/search.md) |
| 产品：搜索参考 | 搜索 API 详情（响应字段、工作流、错误码）— 按需加载 | [references/products/search-reference.md](references/products/search-reference.md) |

## 错误处理

当 `popo-cli` 返回错误时：

1. 读取 `popo-cli` 返回的错误信息
2. 若为认证失败（401/403）：确认 popo-cli 登录状态是否正常（尝试重新登录）
3. 向用户报告完整错误信息（状态码、错误体、命令名）
4. **绝不**静默尝试其他端点或变通方案
5. **绝不**跳过错误继续下一步操作
6. **绝不**尝试通过 `curl`、`requests` 或其他方式直接调用 API 作为替代

## 兜底 HTTP 直传

若 `popo-cli` 参数解析失败（如数组/对象参数类型错误），改用 HTTP 直传重试：

```bash
popo-cli call POST /api/v1/open-apis/gateway/appcode/km/_invoke \
  --body "{\"tool\":\"<原始工具名>\",\"params\":{...}}"
```
