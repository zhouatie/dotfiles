# 文档 API 参考

> 文档域的 API 参考。当意图路由至文档或阅读域时按需加载。

> ⚠️ **执行约束**：本文档所有操作必须通过 `popo-cli` 命令执行，禁止直接调用 API 端点。

## popo-cli 命令

### 文章安全阅读（已启用）

| popo-cli 命令 | 描述 |
|---------------|------|
| `popo-cli km resource_outline` | 获取文章大纲（不含正文） |
| `popo-cli km resource_section` | 获取文章章节内容 |

> 底层端点（仅供参考）：
> - `popo-cli km resource_outline` → `POST /open-api/v1/cms/resource/outline`
> - `popo-cli km resource_section` → `POST /open-api/v1/cms/resource/section`
> 以上路径仅供了解底层映射，skill 执行时必须使用 `popo-cli` 命令。

> **注意**：认证由 popo-cli 自动处理，无需手动配置。

## popo-cli km resource_outline

获取文章大纲（不返回正文内容）。

> 底层端点（仅供参考）：`POST /open-api/v1/cms/resource/outline`

### 请求（URL 模式，推荐）

```bash
popo-cli km resource_outline url=https://km.netease.com/v4/detail/blog/22594
```

### 请求（类型+ID 模式）

```bash
popo-cli km resource_outline resourceType=blog resourceId=22594
```

### 响应

```json
{
  "status": 1,
  "data": {
    "resourceType": "blog",
    "resourceId": 22594,
    "title": "文章标题",
    "author": "作者姓名",
    "editorLanguage": "markdown",
    "sections": [
      { "index": 0, "title": "引言", "level": 1 },
      { "index": 1, "title": "第一章", "level": 2 }
    ]
  }
}
```

## popo-cli km resource_section

获取文章章节内容。

> 底层端点（仅供参考）：`POST /open-api/v1/cms/resource/section`

### 请求

```bash
popo-cli km resource_section resourceType=blog resourceId=22594 sectionIndex=2
```

`sectionIndex` = -1 时获取全文。

### 响应

```json
{
  "status": 1,
  "data": {
    "sectionIndex": 2,
    "sectionTitle": "架构设计",
    "content": "## 架构设计\n\n本系统采用微服务架构..."
  }
}
```

## 意图映射

| 用户输入 | popo-cli 命令 |
|----------|---------------|
| "阅读这篇文章 URL" | `popo-cli km resource_outline` |
| "打开文章 22594" | `popo-cli km resource_outline` |
| "分析第 2 章" | `popo-cli km resource_section` |
| "总结全文" | `popo-cli km resource_section`（sectionIndex=-1） |

## 意图分类

当用户输入被路由到阅读域时，分类为以下意图类型之一：

| 意图 | 触发条件 | 示例 |
|------|----------|------|
| `read_outline` | URL 或文章引用，"阅读/打开/查看" + 文章 | "阅读这篇文章 https://km.../blog/22594" |
| `read_section` | 章节/段落编号引用 | "分析第 2 章"、"读第 3 章"、"下一章" |
| `read_full` | 全文总结或分析请求 | "总结全文"、"概括整篇文章" |

### 中文触发词

| 意图 | 触发词 |
|------|--------|
| `read_outline` | "看这篇文章"、"读这篇文章"、"打开文章"、"帮我看看文章 N" |
| `read_section` | "分析第N章"、"读第N章"、"看看第N章"、"第N章呢"、"下一章" |
| `read_full` | "总结全文"、"概括整篇文章"、"帮我总结整篇文章" |

## 参数提取

| 参数 | 提取模式 | 映射到 popo-cli 参数 |
|------|----------|----------------------|
| URL | 用户输入中的 `https?://km\.netease\.com/...` 模式 | `url` |
| 资源类型 | "blog"/"page" 关键词，或从 URL 推断 | `resourceType` |
| 资源 ID | 类型后的数字 ID 或 URL 路径中的数字 | `resourceId` |
| 章节索引 | "section/chapter/第N章" 后的数字值 | `sectionIndex` |

## 上下文记忆

- 成功调用 `popo-cli km resource_outline` 后，记住响应中的 `resourceType` 和 `resourceId`
- 后续 `read_section` 和 `read_full` 意图自动复用这些值
- 若上下文缺失（如用户直接说"读第 3 章"但未先获取大纲），提示："请先使用 `/km:read <url>` 打开文章获取目录。"
- 请求"下一章"时，将上次阅读的章节索引加 1

## 核心工作流：文章安全阅读

```bash
# 1. 获取文章大纲（不返回正文内容）
popo-cli km resource_outline url=https://km.netease.com/v4/detail/blog/22594

# 2. 阅读特定章节（用户授权后）
# 使用大纲响应中的 resourceType 和 resourceId
popo-cli km resource_section resourceType=blog resourceId=22594 sectionIndex=2
```

## 执行

大纲请求（URL 模式）：
```bash
popo-cli km resource_outline url={article_url}
```

大纲请求（类型+ID 模式）：
```bash
popo-cli km resource_outline resourceType={type} resourceId={id}
```

章节请求：
```bash
popo-cli km resource_section resourceType={type} resourceId={id} sectionIndex={n}
```

全文请求（用户确认后）：
```bash
popo-cli km resource_section resourceType={type} resourceId={id} sectionIndex=-1
```

## 结果格式化

### 大纲格式化

将 `popo-cli km resource_outline` 返回的 JSON 格式化为：

```
{title}
作者: {author}

| # | 章节 |
|---|------|
| {index} | {section.title} |
| ... | ... |

文章内容尚未发送给 AI。
告诉我章节编号即可分析该章节。
```

### 章节格式化

当 `popo-cli km resource_section` 返回章节内容时：
1. 对章节内容执行用户请求的分析/总结
2. 分析完成后追加："需要阅读其他章节吗？"

### 全文确认

执行全文阅读前：
1. 展示："阅读全文将把所有内容发送给 AI 进行分析。是否继续？（是/否）"
2. 仅在用户明确确认后执行 `popo-cli km resource_section resourceType={type} resourceId={id} sectionIndex=-1`
3. 若用户拒绝，建议："你可以改为阅读特定章节。告诉我章节编号。"

## 安全约束

1. **默认不泄露内容** — `popo-cli km resource_outline` 仅返回大纲结构；文章正文在用户明确请求章节前不会进入 LLM 上下文
2. **逐章授权** — 当用户说"读第 N 章"时，仅第 N 章内容进入 LLM 上下文；其他章节不可见
3. **全文需确认** — 全文阅读（`sectionIndex: -1`）需在执行前获得用户明确确认
4. **已知风险** — 确认机制是 prompt 级指令（LLM 行为约束），非硬性技术门控。实际数据流是安全的：LLM 无法捏造未通过 popo-cli 输出接收的文章内容

## 上下文链表

| 操作 | 从响应中提取 | 用于 |
|------|-------------|------|
| 获取大纲 | `data.resourceType`、`data.resourceId` | 章节阅读的 `resourceType`、`resourceId` 参数 |
| 获取大纲 | `data.sections[].index` | 章节阅读的 `sectionIndex` 参数 |
| 获取章节 | `data.content` | LLM 分析（仅在用户授权后进入上下文） |

## 注意事项

- 文章安全阅读默认仅返回大纲（LLM 上下文中无正文内容）
- 章节内容仅在用户明确请求后进入 LLM 上下文
- 全文阅读（sectionIndex=-1）需在执行前获得用户确认
- 文档内容支持 Markdown 格式
- 时间戳为 ISO 8601 UTC
