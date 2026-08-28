# POPO Notebook 工具参考

所有操作通过 Bash 执行 `popo-cli popo <工具名> key=value` 命令完成，本 skill 对外暴露 11 个 MCP 业务 tool（MCP 工具名统一带 `popo_` 前缀，CLI 命令使用去掉前缀后的工具名）。

添加本地文件的入口是 `popo-cli popo notebook_add_file`。它是 popo-cli 的 Skill 路由指令：负责加载本 SKILL.md，不是 MCP 业务 tool。Skill 加载后执行 [`scripts/add_file_to_notebook.py`](#本地文件上传脚本)；脚本内所有 notebook API 仍通过 `popo-cli popo`，只有上传到外部存储预签名地址的 PUT 直接 HTTP。网址与纯文本仍走 [`popo_notebook_add_article`](#popo_notebook_add_article)。

> **参数值引号规则（跨平台兼容，禁止使用单引号）**
>
> 为确保命令在 bash、CMD、PowerShell 等不同 shell 下均能正确执行，统一使用**双引号**作为引用符：
> - 简单值（无空格、无特殊字符）**不加引号**：`key=value`
> - 含空格、中文或特殊字符的值用**双引号**包裹：`name="项目资料"`
> - **macOS / Linux**：JSON 数组/对象用双引号包裹，内部双引号使用 `\"` 转义
> - **Windows**：`\"` 转义在 PowerShell 中不可靠，JSON 数组/对象参数**强制走临时文件**：
>   - **Array/Object 参数**（如 `slugs`）→ `@file:` — popo-cli 将文件内容解析为 JSON 值（数组/对象）后传参
>   - **String 参数（含中文/特殊字符）**（如 `name` / `title` / `query`）→ `@text:` — popo-cli 读取文件内容作为纯文本字符串传参
>   - 标准流程：PowerShell 对象 → `ConvertTo-Json -Compress` → `[System.IO.File]::WriteAllText` (UTF-8 无 BOM) → `key="@file:$path"` 或 `key="@text:$path"`
>
> ```bash
> # ✅ macOS / Linux — 简单值
> popo-cli popo notebook_readable_list
>
> # ✅ macOS / Linux — 含中文，双引号包裹
> popo-cli popo notebook_create name="项目资料"
>
> # ✅ macOS / Linux — 数组，双引号包裹 + 内部 \" 转义
> popo-cli popo notebook_list knowledgeBaseId=123456 slugs="[\"service-release-guide\",\"/entity/test.md\"]"
>
> # ❌ 错误：使用单引号
> popo-cli popo notebook_list knowledgeBaseId=123456 slugs='["service-release-guide"]'
> ```
>
> ```powershell
> # ✅ Windows (PowerShell) — Array 参数（slugs）：@file: 临时文件
> $slugs = @("service-release-guide", "/entity/test.md")
> $json = ConvertTo-Json -InputObject $slugs -Compress
> $tmp = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).json"
> try {
>     [System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
>     popo-cli popo notebook_list knowledgeBaseId=123456 slugs="@file:$tmp"
> }
> finally {
>     Remove-Item -Path $tmp -ErrorAction SilentlyContinue
> }
>
> # ✅ Windows (PowerShell) — 含中文/特殊字符的 String（@text:）
> $name = "项目资料"
> $tmp = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).txt"
> try {
>     [System.IO.File]::WriteAllText($tmp, $name, [System.Text.UTF8Encoding]::new($false))
>     popo-cli popo notebook_create name="@text:$tmp"
> }
> finally {
>     Remove-Item -Path $tmp -ErrorAction SilentlyContinue
> }
> ```
>
> 🚫 **Windows 平台绝对禁止**：
> - ❌ `slugs="[\"slug\"]"` — PowerShell 下 `\"` 不可靠，服务端收到裸字符串
> - ❌ 手工字符串拼接 JSON（`'["' + $a + '"]'`）
> - ❌ 使用 `Set-Content -Encoding UTF8`（PS 5.1 写 BOM）或 `Out-File`（默认 UTF-16）
>
> > **`@file:` vs `@text:` 语义区别**
> > - `@file:` — popo-cli 读取文件内容，**解析为 JSON 值**（数组/对象），用于 `slugs` 等 Array/Object 类型参数
> > - `@text:` — popo-cli 读取文件内容，作为**纯文本字符串**传参，用于 `name` / `title` / `query` / `description` 等 String 类型参数
> > - 两者**不可混用**：Array 参数用 `@text:` 传 JSON 字符串会被服务端当成字符串而非数组

---

## 统一响应处理

所有 notebook 工具返回统一对齐 `Response<T>`：

| 字段 | 类型 | 说明 |
|------|------|------|
| `status` | Integer | `1` 表示成功 |
| `message` | String | 成功或失败消息 |
| `data` | T | 业务数据 |

判断规则：
- `status=1`：成功，读取 `data`。
- 失败：读取 `message` 或错误信息，向用户说明；必要时按错误提示调整参数重试一次。
- `Void` 返回成功时 `data` 可能为空。

> **数组返回字段的展示（跨平台）**
>
> `notebook_readable_list` / `notebook_writable_list` 返回 `data` 为知识本数组、`notebook_article_list` 返回 `data.records` 为文章数组、`notebook_search` / `notebook_list` 返回 `data` 为 Wiki 页数组。展示时用 `jq` 提取数组元素并逐条呈现，不要原样倾倒 JSON：
> ```bash
> # 知识本列表
> popo-cli popo notebook_readable_list | jq '.data[] | {id, name, description, role}'
> # 文章列表 records 数组
> popo-cli popo notebook_article_list knowledgeBaseId=123456 | jq '.data.records[] | {articleId, title, url}'
> ```
> Windows 下同样用 `popo-cli ... | jq`（PowerShell 管道兼容），不要手动切片 JSON 文本。

---

## popo_notebook_readable_list

获取当前用户所有有权限读取的知识本。可用于检索、读取、导出前选择知识本。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `keyword` | String | 否 | 按知识本名称关键词过滤 |

### 返回值

`data` 为 `List<AiKnowledgeBaseResp>`：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | Long | 知识本 ID |
| `name` | String | 名称 |
| `ownerUid` | String | 创建人 uid |
| `ownerName` | String | 创建人姓名 |
| `role` | String | 当前用户角色 |
| `description` | String | 描述 |
| `sourceCount` | Integer | 来源条数 |
| `createdAt` | String | 创建时间 |

### 示例

```bash
# macOS / Linux
popo-cli popo notebook_readable_list
popo-cli popo notebook_readable_list keyword="项目"
```

```powershell
# Windows — 含中文 keyword 走 @text:
$kw = "项目"
$tmp = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($tmp, $kw, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo notebook_readable_list keyword="@text:$tmp"
}
finally {
    Remove-Item -Path $tmp -ErrorAction SilentlyContinue
}
```

---

## popo_notebook_writable_list

获取当前用户所有可写知识本。创建文章、更新知识本、删除文章、删除知识本前优先使用。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `keyword` | String | 否 | 按知识本名称关键词过滤 |

### 返回值

`data` 为 `List<AiKnowledgeBaseResp>`，字段同 [`popo_notebook_readable_list`](#popo_notebook_readable_list)。

### 示例

```bash
popo-cli popo notebook_writable_list
popo-cli popo notebook_writable_list keyword="项目"
```

---

## popo_notebook_create

创建知识本。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `name` | String | 是 | 知识本名称，1-128 字符 |
| `description` | String | 否 | 知识本描述，最多 512 字符 |

### 返回值

`data` 为 `AiCreateKnowledgeBaseResp`：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | Long | 知识本 ID |
| `ownerUid` | String | 拥有者 uid |
| `name` | String | 名称 |
| `description` | String | 描述 |
| `createdAt` | String | 创建时间 |

### 示例

```bash
popo-cli popo notebook_create name="项目资料" description="沉淀项目设计、会议纪要和参考资料"
```

```powershell
# Windows — name / description 含中文，各走 @text: 临时文件
$name = "项目资料"
$desc = "沉淀项目设计、会议纪要和参考资料"
$tmpName = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).txt"
$tmpDesc = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($tmpName, $name, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($tmpDesc, $desc, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo notebook_create name="@text:$tmpName" description="@text:$tmpDesc"
}
finally {
    Remove-Item -Path $tmpName, $tmpDesc -ErrorAction SilentlyContinue
}
```

---

## popo_notebook_update

更新知识本名称或描述。写权限必要。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `knowledgeBaseId` | Long | 是 | 知识本 ID |
| `name` | String | 否 | 新名称，1-128 字符；不传则不修改 |
| `description` | String | 否 | 新描述，最多 512 字符；不传则不修改 |

### 返回值

`Void`（成功时 `data` 可能为空）。

### 示例

```bash
popo-cli popo notebook_update knowledgeBaseId=123456 name="项目资料库" description="项目资料、方案和会议纪要"
```

### 使用注意

- `name` 与 `description` 至少应提供一个。
- 如果用户只给了知识本名称，先用 `popo_notebook_writable_list` 定位 `knowledgeBaseId`。

---

## popo_notebook_delete

删除知识本。写权限必要。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `knowledgeBaseId` | Long | 是 | 知识本 ID |

### 返回值

`Void`（成功时 `data` 可能为空）。

### 示例

```bash
popo-cli popo notebook_delete knowledgeBaseId=123456
```

### 使用注意

- 这是破坏性操作。除非用户明确要求删除具体 ID，否则先确认知识本名称和 ID。

---

## popo_notebook_add_article

向知识本添加单篇文章。支持 URL 或纯文本内容。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `knowledgeBaseId` | Long | 是 | 知识本 ID |
| `url` | String | 否 | 文章 URL；与 `content` 二选一。`url` 有值时优先按 URL 入库并忽略 `content` |
| `title` | String | 否 | 文章标题，最多 512 字符；不传时 URL 场景由系统解析，纯文本场景从内容截取 |
| `content` | String | 否 | 文章正文；与 `url` 二选一。仅在 `url` 为空时生效，按纯文本入库 |

### 返回值

`data` 为 `AiCreateArticleResp`：

| 字段 | 类型 | 说明 |
|------|------|------|
| `articleId` | Long | 文章 ID |
| `title` | String | 标题 |
| `url` | String | 链接地址 |

### 示例

添加链接：

```bash
popo-cli popo notebook_add_article knowledgeBaseId=123456 url="https://example.com/article/123" title="需求设计文档"
```

添加纯文本：

```bash
popo-cli popo notebook_add_article knowledgeBaseId=123456 title="会议纪要" content="这里是会议纪要正文..."
```

```powershell
# Windows — content 含中文/多行，必须走 @text: 临时文件
$content = "这里是会议纪要正文..."
$title = "会议纪要"
$tmpContent = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).txt"
$tmpTitle = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($tmpContent, $content, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($tmpTitle, $title, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo notebook_add_article knowledgeBaseId=123456 title="@text:$tmpTitle" content="@text:$tmpContent"
}
finally {
    Remove-Item -Path $tmpContent, $tmpTitle -ErrorAction SilentlyContinue
}
```

### 使用注意

- `url` 与 `content` 不能同时为空。
- 同时提供 `url` 和 `content` 时，以 `url` 为准。
- ⛔ **本地文件不能用这个工具**：把本地路径（`D:\a.pdf`、`file:///...`）或存储服务预签名地址传给 `url`，会被当成网页链接抓取，结果错误。本地文件一律走[本地文件上传脚本](#本地文件上传脚本)。

---

## popo_notebook_delete_article

从知识本删除文章。写权限必要。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `knowledgeBaseId` | Long | 是 | 知识本 ID |
| `articleId` | Long | 是 | 文章 ID |

### 返回值

`Void`（成功时 `data` 可能为空）。

### 示例

```bash
popo-cli popo notebook_delete_article knowledgeBaseId=123456 articleId=987654
```

### 使用注意

- 这是破坏性操作。用户没有给 `articleId` 时，先用 `popo_notebook_article_list` 找文章，再确认删除目标。

---

## popo_notebook_article_list

分页列出知识本中的文章来源。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `knowledgeBaseId` | Long | 是 | 知识本 ID |
| `pageNo` | Long | 否 | 页码，从 1 开始；不传默认第 1 页 |
| `pageSize` | Integer | 否 | 每页条数；不传默认 20，最大 100 |

### 返回值

`data` 为 `ArticleBriefPageDTO`：

| 字段 | 类型 | 说明 |
|------|------|------|
| `records` | List\<ArticleBriefDTO\> | 当前页记录 |
| `pageNo` | Long | 当前页码 |
| `pageSize` | Integer | 每页条数 |
| `hasMore` | Boolean | 是否还有更多 |

`ArticleBriefDTO`：

| 字段 | 类型 | 说明 |
|------|------|------|
| `articleId` | Long | 文章 ID |
| `title` | String | 文章标题 |
| `url` | String | 文章 URL |

### 示例

```bash
# macOS / Linux
popo-cli popo notebook_article_list knowledgeBaseId=123456
popo-cli popo notebook_article_list knowledgeBaseId=123456 pageNo=1 pageSize=20

# 提取 records 数组逐条展示
popo-cli popo notebook_article_list knowledgeBaseId=123456 | jq '.data.records[] | {articleId, title, url}'
```

### 使用注意

- **`records` 是数组字段**：展示时必须按数组逐条呈现（`jq '.data.records[]'`），并检查 `hasMore` 决定是否提示翻页；`pageNo`/`pageSize` 用于构造下一页请求。
- 该工具返回的是文章来源列表，不是知识 Wiki 正文。读取 Wiki 正文使用 `popo_notebook_search` 或 `popo_notebook_list`。

---

## popo_notebook_search

在指定知识本内检索知识。根据自然语言问题返回相关 Wiki 页面或片段。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `knowledgeBaseId` | Long | 是 | 知识本 ID |
| `query` | String | 是 | 用户问题或搜索关键词 |
| `topK` | Integer | 否 | 返回 topK；不传走默认值，超过上限按上限处理 |

### 返回值

`data` 为 `List<WikiSearchHit>`：

| 字段 | 类型 | 说明 |
|------|------|------|
| `slug` | String | Wiki page slug；原文检索时可能返回原文 chunk id |
| `title` | String | Wiki page 标题 |
| `content` | String | Wiki page 正文或片段，可能被截断 |

### 示例

```bash
# macOS / Linux
popo-cli popo notebook_search knowledgeBaseId=123456 query="服务发布流程" topK=5

# 提取数组逐条展示
popo-cli popo notebook_search knowledgeBaseId=123456 query="服务发布流程" | jq '.data[] | {slug, title, content}'
```

```powershell
# Windows — query 含中文走 @text:
$query = "服务发布流程"
$tmp = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($tmp, $query, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo notebook_search knowledgeBaseId=123456 query="@text:$tmp" topK=5
}
finally {
    Remove-Item -Path $tmp -ErrorAction SilentlyContinue
}
```

### 使用注意

- `query` 应是自然语言问题或搜索关键词，不是页面 slug。
- 如果用户已经提供明确 slug，不要把 slug 传给 `popo_notebook_search.query`；应调用 `popo_notebook_list`。
- 如果不知道 `knowledgeBaseId`，先用 `popo_notebook_readable_list` 找候选知识本。

---

## popo_notebook_list

根据 slugs 精确查询指定知识本中的 Wiki 页面列表，返回页面正文。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `knowledgeBaseId` | Long | 是 | 知识本 ID |
| `slugs` | List\<String\> | 是 | kb 内唯一 slug 列表，每个元素不能为空字符串 |

### 返回值

`data` 为 `List<AiWikiPageResp>`：

| 字段 | 类型 | 说明 |
|------|------|------|
| `slug` | String | kb 内唯一 slug |
| `title` | String | Wiki page 标题 |
| `content` | String | Wiki page 正文 |

### 示例

```bash
# macOS / Linux — slugs 数组，双引号包裹 + 内部 \" 转义
popo-cli popo notebook_list knowledgeBaseId=123456 slugs="[\"service-release-guide\",\"/entity/test.md\"]"

# 提取数组逐条展示
popo-cli popo notebook_list knowledgeBaseId=123456 slugs="[\"service-release-guide\"]" | jq '.data[] | {slug, title, content}'
```

```powershell
# ✅ Windows — slugs 是 Array 参数，必须走 @file: 临时文件
$slugs = @("service-release-guide", "/entity/test.md")
$json = ConvertTo-Json -InputObject $slugs -Compress
$tmp = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).json"
try {
    [System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo notebook_list knowledgeBaseId=123456 slugs="@file:$tmp"
}
finally {
    Remove-Item -Path $tmp -ErrorAction SilentlyContinue
}
```

### 使用注意

- `slugs` 必填且不能为空，且为**数组类型**（Windows 平台必须走 `@file:`，禁止 `\"` 转义直传）。
- slug 可以由用户直接提供，也可以来自 `popo_notebook_search` 返回内容中的引用。
- 不要把 title 当 slug。

---

## popo_notebook_export

导出指定知识本。

### 参数

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `knowledgeBaseId` | Long | 是 | 知识本 ID |

### 返回值

`data` 为 `AiWikiExportResp`：

| 字段 | 类型 | 说明 |
|------|------|------|
| `downloadUrl` | String | S3 临时下载链接 |
| `fileName` | String | 导出文件名 |
| `expiresSeconds` | Integer | 临时链接有效期，单位秒 |

### 示例

```bash
popo-cli popo notebook_export knowledgeBaseId=123456
```

### 使用注意

- 如果用户只给了知识本名称，先用 `popo_notebook_readable_list` 定位 `knowledgeBaseId`。

---

## 本地文件上传脚本

把**本地文件**添加到知识本。`notebook_add_file` 是路由指令，不是 MCP 业务 tool。调用时将参数传给路由，路由加载 Skill MD 后，Skill 再引导模型执行 Python 脚本：

```bash
# knowledgeBaseId 可选；files 是 JSON 文件数组
popo-cli popo notebook_add_file knowledgeBaseId=123456 files="@file:/tmp/popo_nb_files.json"

# 路由参数结构：files=[{"path":"/docs/design.pdf","title":"设计文档"}]
```

路由参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `knowledgeBaseId` | Long | 否 | 已知知识本 ID；不传时 Skill 先调用 `notebook_writable_list` 定位 |
| `files` | List<Object> | 是 | 本地文件对象数组；每项包含 `path`，可选 `title`；数量、类型和大小以服务端实际返回为准 |

路由加载 Skill 后，模型实际执行脚本，例如：

```bash
python scripts/add_file_to_notebook.py --kb-id 123456 --file "/docs/design.pdf"
```

内部脚本 `scripts/add_file_to_notebook.py` 串联四步：

1. 通过 `popo-cli popo notebook_file_upload_url` 申请存储服务预签名 PUT 地址
2. 直接 HTTP PUT 文件二进制到该外部存储地址
3. 通过 `popo-cli popo notebook_file_confirm` 确认上传并取得下载地址
4. 通过 `popo-cli popo notebook_add_attachment`，携带 `linkType=attachment` 入库

多文件时逐个上传，**全部上传成功后一次性入库**；任一文件失败则整体不入库，不会产生半成品文章。

依赖：Python 3.8+，仅用标准库，无需 pip 安装。

### 脚本参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `--kb-id` | Integer | 是 | 知识本 ID；写入前先用 `notebook_writable_list` 获取 |
| `--file` | String | 是 | 本地文件路径，可重复传入；数量限制以服务端实际返回为准 |
| `--params-file` | String | 否 | 直接调试脚本时使用的 JSON 参数文件，可指定自定义标题 |
| `--popo-cli` | String | 否 | popo-cli 路径，覆盖 `POPO_CLI_BIN` |
| `--dry-run` | Flag | 否 | 只做本地预检，不请求 popo-cli 或外部存储 |

`--params-file` 调试文件格式：

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `knowledgeBaseId` | Integer | 是 | 知识本 ID |
| `files` | List<Object> | 是 | 文件对象数组 |

`files` 元素：

| 字段 | 类型 | 必填 | 说明 |
|------|------|:---:|------|
| `path` | String | 是 | 本地文件路径 |
| `title` | String | 否 | 文章标题，默认取文件名，限制以服务端实际返回为准 |

脚本内部传给 `popo-cli` 的 `items` 数组会自动使用 `@file:`，避免 shell 引号和中文编码问题。直接运行 `popo-cli` 子工具时，数组临时文件内容（UTF-8 无 BOM）只包含数组：

```json
[
  {"path": "D:\\docs\\设计.pdf", "title": "需求设计文档"},
  {"path": "D:\\docs\\会议纪要.docx"}
]
```

### 鉴权与服务地址

脚本不读取或拼装服务地址、用户 ID、token，也不直接调用知识本 HTTP 接口。
这些都由 `popo-cli` 的登录态、网关和配置负责。脚本只需要找到 `popo-cli`：

- 默认从 PATH 查找 `popo-cli`（Windows 兼容 `popo-cli.ps1`）
- 也可设置 `POPO_CLI_BIN`，或调试时传 `--popo-cli <path>`

### 文件约束

脚本会根据扩展名识别 MIME 类型，识别逻辑与前端一致；未知扩展名回退为 `application/octet-stream`。这不是本地支持类型白名单，文件数量、扩展名、MIME 类型和大小是否允许全部以服务端实际配置和响应为准。

### 返回值

成功（退出码 0）：

```json
{"status": 1, "message": "ok", "data": [
  {"articleId": 987654, "title": "需求设计文档", "url": "https://.../设计.pdf", "file": "D:\\docs\\设计.pdf"}
]}
```

`data` 是数组，按数组逐条展示 `articleId/title/url`，禁止原样倾倒 JSON。

失败（退出码 1）：

```json
{"status": 0, "message": "...", "stage": "upload-url", "file": "D:\\docs\\归档.zip", "rawError": "..."}
```

### 错误 stage 与处置

| stage | 含义 | 处置 |
|-------|------|------|
| `preflight` | 本地预检失败（文件不存在/参数缺失等） | 将 `message` 和 `rawError` 交给模型理解后再反馈 |
| 任意 stage | 脚本/服务端/外部存储失败 | 将 `stage`、`message`、`rawError` 交给模型理解，向用户说明具体原因；不要原样展示 `rawError`，也不要依赖脚本内置的文件类型或大小白名单 |

### 示例

```bash
# macOS / Linux — 直接执行 Skill 脚本
python scripts/add_file_to_notebook.py --kb-id 123456 --file ~/docs/design.pdf --file ~/docs/meeting.docx

# 脚本本地调试：只做预检，不发起 popo-cli 或 HTTP 请求
python scripts\add_file_to_notebook.py --kb-id 123456 --file a.pdf --dry-run
```

```powershell
# Windows — 自定义标题走 @file: 文件数组（UTF-8 无 BOM，同铁律 6 的临时文件套路）
$files = @(
    @{ path = "D:\docs\设计.pdf"; title = "需求设计文档" },
    @{ path = "D:\docs\纪要.docx" }
)
$tmp = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).json"
try {
    [System.IO.File]::WriteAllText($tmp, (ConvertTo-Json $files -Depth 5 -Compress), [System.Text.UTF8Encoding]::new($false))
    python scripts\add_file_to_notebook.py --params-file $tmp
}
finally {
    Remove-Item -Path $tmp -ErrorAction SilentlyContinue
}
```

### 使用注意

- 脚本**不做知识本查找**：`notebook_add_file` 路由加载本 SKILL.md 后，先用 `popo_notebook_writable_list` 拿到 `knowledgeBaseId`（铁律 3）。
- 脚本不接收 notebook 服务地址和鉴权参数；这些由 `popo-cli` 负责。
- 直接运行 Python 脚本时，`--params-file` 仍接受带 `knowledgeBaseId` 和 `files` 的调试参数文件；agent 正常调用不使用该入口。
- 标题默认取文件名；直接调试脚本时可在 `--params-file` 的 `files` 数组对象中传 `title`。
- ⛔ 禁止用 `popo_notebook_add_article` 传本地文件路径或预签名地址（铁律 7）。
- ✅ 网址、纯文本不受影响，仍走 `popo_notebook_add_article`，不要用本脚本。

### popo-cli 内部子工具契约

编排脚本会通过当前用户的 `popo-cli` 依次调用以下三个 notebook 子工具；它们不是 agent 直接选择的入口，但必须由 popo-cli 的 notebook provider/MCP tool 注册提供。`notebook_add_file` 仅是 Skill 路由，不在此表中注册：

| CLI 子工具 | 方法/接口语义 | 请求参数 | 成功 `data` |
|---|---|---|---|
| `notebook_file_upload_url` | `POST /api/base-notebook/v1/ai/knowledge-bases/articles/file/upload-url` | `knowledgeBaseId`、`filename`、`fileSize`、`mimeType` | `uploadUrl`、`objectKey`、`expiresIn` |
| `notebook_file_confirm` | `POST /api/base-notebook/v1/ai/knowledge-bases/articles/file/confirm` | `knowledgeBaseId`、`objectKey`、`filename`、`fileSize`、`mimeType` | `filename`、`mimeType`、`downloadUrl`、`fileSize` |
| `notebook_add_attachment` | `POST /api/base-notebook/v1/ai/knowledge-bases/articles/attachments` | `knowledgeBaseId`、`items`（数组，元素含 `url`、`name`、`mimeType`、`fileSize`、`linkType=attachment`） | `articleId`、`title`、`url` 数组 |

只有第一步返回的 `uploadUrl` 会被脚本直接用于外部存储 HTTP `PUT`；脚本不得绕过 popo-cli 直接请求上表中的 notebook API。
