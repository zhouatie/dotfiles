---
name: popo-notebook
description: "POPO 知识本（Notebook / Knowledge Base）管理：新建/改名/删除知识本、添加/删除文章、上传本地文件、查看文章列表、知识检索、根据 slug 读取 Wiki 正文、导出知识本。触发场景：(1) 知识本管理 —\"我有哪些知识本\"、\"能写哪些知识本\"、\"新建一个知识本\"、\"把知识本改名为 XX\"、\"删除这个知识本\"；(2) 文章维护 —\"把这个链接加入知识本\"、\"把这段内容存进知识本\"、\"把这个 PDF/文档/文件上传到知识本\"、\"从知识本里删掉这篇文章\"；(3) 内容查询 —\"这个知识本里有哪些文章/来源\"、\"在 XX 知识本里搜一下关于 Y 的内容\"、\"查一下知识本里这篇文章的正文\"、\"把知识本导出\"。当用户输入内容涉及 Notebook/知识本/知识库/KB 的任何管理、检索、读取或导出意图时，都应使用此 skill。"
---

# POPO Notebook Skill

所有操作通过 Bash 执行 `popo-cli popo <工具名> key=value` 命令完成，本 skill 对外提供现有的 11 个 MCP 知识本工具。
本地文件另有一个由 `popo-cli` 路由层识别的入口 `notebook_add_file`：它不是 Fabric 业务工具，
而是用于加载本 SKILL.md；Skill 加载后再按本文引导执行
[`scripts/add_file_to_notebook.py`](./scripts/add_file_to_notebook.py)。脚本只有上传到外部存储的
PUT 请求直接走 HTTP，所有知识本接口仍必须通过 `popo-cli popo`（见[铁律 7](#铁律-7本地文件必须走脚本)）。

> **参数值引号规则（跨平台兼容，禁止使用单引号）**
>
> 为确保命令在 bash、CMD、PowerShell 等不同 shell 下均能正确执行，统一使用**双引号**作为引用符：
> - 简单值（无空格、无特殊字符）**不加引号**：`key=value`
> - 含空格、中文或特殊字符的值用**双引号**包裹：`name="项目资料"`
> - **macOS / Linux**：JSON 数组/对象用双引号包裹，内部双引号使用 `\"` 转义
> - **Windows**：`\"` 转义在 PowerShell 中不可靠，JSON 数组/对象参数**强制走临时文件**：
>   - **Array/Object 参数**（如 `slugs`）→ `@file:` — popo-cli 将文件内容解析为 JSON 值（数组/对象）后传参
>   - **String 参数（含中文/特殊字符）**（如 `name` / `title` / `query` / `content` / `description`）→ `@text:` — popo-cli 读取文件内容作为纯文本字符串传参
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
> - ❌ `slugs="[\"service-release-guide\"]"` — PowerShell 下 `\"` 不可靠，服务端收到裸字符串
> - ❌ 手工字符串拼接 JSON（`'["' + $a + '"]'`）
> - ❌ 使用 `Set-Content -Encoding UTF8`（PS 5.1 写 BOM）或 `Out-File`（默认 UTF-16）
>
> > **`@file:` vs `@text:` 语义区别**
> > - `@file:` — popo-cli 读取文件内容，**解析为 JSON 值**（数组/对象），用于 `slugs` 等 Array/Object 类型参数
> > - `@text:` — popo-cli 读取文件内容，作为**纯文本字符串**传参，用于 `name` / `title` / `query` / `content` / `description` 等 String 类型参数
> > - 两者**不可混用**：Array 参数用 `@text:` 传 JSON 字符串会被服务端当成字符串而非数组，导致 `Cannot construct instance of ArrayList`

---

## ⛔ 七条铁律（每次操作前必须检查）

**铁律 1：参数严格按字段表**
所有调用的 popo-cli 命令，**必须**到 [`references/tool-reference.md`](./references/tool-reference.md) 查询相应工具的参数说明，不得随意捏造字段名、字段类型、枚举值。

**铁律 2：调用前必读 tool-reference**
所有知识本操作（读或写）调用前，必须先读 [`references/tool-reference.md`](./references/tool-reference.md) 确认参数与返回结构；不要捏造字段。返回值中的数组字段（`notebook_readable_list`/`notebook_writable_list`/`notebook_search`/`notebook_list` 的 `data`、`notebook_article_list` 的 `data.records`）必须按数组逐条展示，禁止原样倾倒 JSON。

**铁律 3：用户没给 knowledgeBaseId 时先查候选**
- 检索/读取/导出前不知道知识本 ID → 先用 `notebook_readable_list` 找候选知识本
- 创建文章/更新/删除前不知道知识本 ID → 先用 `notebook_writable_list` 找可写知识本
- 写操作必须基于可写知识本

**铁律 4：`notebook_search` 与 `notebook_list` 严格区分**
- `notebook_search`：指定知识本内的自然语言检索；`knowledgeBaseId` 必填，`query` 是用户问题或搜索关键词。**不要把 slug 当 query。**
- `notebook_list`：按已知 slug 精确读取知识内容；`knowledgeBaseId` 和非空 `slugs`（数组）必填。**不要把 slug 当成搜索 query，不要把 title 当 slug。**
- `notebook_search` 返回正文中出现引用 slug 且需要展开阅读时：提取 slug 后用 `notebook_list` 读取。

**铁律 5：破坏性操作必须先确认**
删除知识本（`notebook_delete`）或删除文章（`notebook_delete_article`）前，除非用户明确要求删除具体 ID，否则必须先向用户确认目标。

**铁律 6：Windows 平台数组/对象参数强制走 @file: / @text: 临时文件（每次构造 popo-cli 命令前必检）**
- ⛔ **Windows (PowerShell) 下绝对禁止**用 `\"` 转义 JSON 数组/对象参数（如 `slugs="[\"slug\"]"`），PowerShell 不识别 `\"` 转义语义，会原样传递导致服务端收到字符串而非数组，触发 `Cannot construct instance of ArrayList` 错误
- ✅ Array/Object 参数（`slugs` 等）→ **`@file:`** 临时文件标准流程（见上方 PowerShell 示例）
- ✅ String 参数含中文/特殊字符（`name` / `title` / `query` / `content` / `description` / `keyword` / `url`）→ **`@text:`** 临时文件；ASCII 纯字符串可直传
- 🚫 禁止 `ConvertTo-Json` 后手工拼接 shell 字符串、禁止 `Set-Content -Encoding UTF8`（PS 5.1 带 BOM）、禁止 `Out-File`（默认 UTF-16）
- 详细示例见 [`references/tool-reference.md`](./references/tool-reference.md) 头部规则与各工具 Windows 示例

**铁律 7：本地文件必须走 `notebook_add_file` 路由并执行脚本**
- 用户要把**本地文件**（PDF/Word/Excel/Markdown/图片/视频等）加入知识本时，先执行 `popo-cli popo notebook_add_file` 加载本 SKILL.md，再按本文引导执行 [`scripts/add_file_to_notebook.py`](./scripts/add_file_to_notebook.py)，不要把它伪装成 `notebook_add_article` 的 URL 或文本。
- 脚本内部的申请上传地址、确认上传、添加 attachment 请求必须继续通过已注册的 `popo-cli popo` 子工具；只有拿到预签名地址后的文件二进制 PUT 可以直接 HTTP 请求外部存储服务。
- 脚本不限制文件数量、扩展名、MIME 类型或大小，全部以服务端实际返回为准。
- 脚本会根据扩展名识别 MIME 类型；未知扩展名回退为 `application/octet-stream`，不代表本地放行或拒绝，最终仍以服务端返回为准。
- ⛔ **绝对禁止**把本地文件路径当 `url` 传给 `notebook_add_article`（`url=D:\a.pdf` 或 `url=file:///...`），也禁止手工拼预签名地址调用 `notebook_add_article`——文件必须按 attachment 类型入库，走 `notebook_add_article` 会被当成网页链接抓取，结果错误。
- ⛔ **禁止**为了"省事"把文件内容读出来塞进 `content`——除非用户明确要求只存文本摘要。
- ✅ **网址、纯文本不受影响**：仍然走 `popo-cli popo notebook_add_article`，不要用脚本。

---

## 工具速查

| 操作 | MCP tool | CLI 命令 | 参考 |
|------|----------|----------|------|
| 获取所有有权限的知识本 | `popo_notebook_readable_list` | `popo-cli popo notebook_readable_list` | [详情](./references/tool-reference.md#popo_notebook_readable_list) |
| 获取所有可写的知识本 | `popo_notebook_writable_list` | `popo-cli popo notebook_writable_list` | [详情](./references/tool-reference.md#popo_notebook_writable_list) |
| 创建知识本 | `popo_notebook_create` | `popo-cli popo notebook_create` | [详情](./references/tool-reference.md#popo_notebook_create) |
| 更新知识本 | `popo_notebook_update` | `popo-cli popo notebook_update` | [详情](./references/tool-reference.md#popo_notebook_update) |
| 删除知识本 | `popo_notebook_delete` | `popo-cli popo notebook_delete` | [详情](./references/tool-reference.md#popo_notebook_delete) |
| 知识本添加文章 | `popo_notebook_add_article` | `popo-cli popo notebook_add_article` | [详情](./references/tool-reference.md#popo_notebook_add_article) |
| **上传本地文件到知识本** | Skill 路由（非 Fabric tool） | `popo-cli popo notebook_add_file knowledgeBaseId=<id> files="@file:<tmp>"` → 加载本 SKILL.md → 执行脚本 | [详情](./references/tool-reference.md#本地文件上传脚本) |
| 知识本删除文章 | `popo_notebook_delete_article` | `popo-cli popo notebook_delete_article` | [详情](./references/tool-reference.md#popo_notebook_delete_article) |
| 知识本文章列表 | `popo_notebook_article_list` | `popo-cli popo notebook_article_list` | [详情](./references/tool-reference.md#popo_notebook_article_list) |
| 知识检索 | `popo_notebook_search` | `popo-cli popo notebook_search` | [详情](./references/tool-reference.md#popo_notebook_search) |
| 批量根据 slug 查询知识内容 | `popo_notebook_list` | `popo-cli popo notebook_list` | [详情](./references/tool-reference.md#popo_notebook_list) |
| 知识本导出 | `popo_notebook_export` | `popo-cli popo notebook_export` | [详情](./references/tool-reference.md#popo_notebook_export) |

关键区分：
- `notebook_add_article`：加**网址**或**纯文本**。
- `notebook_add_file`：本地文件 Skill 路由入口，不是 Fabric 业务工具；加载本 SKILL.md 后执行 `scripts/add_file_to_notebook.py`。
- `notebook_readable_list`：找用户能读的知识本，适合检索、读取、导出前选择目标。
- `notebook_writable_list`：找用户能写的知识本，适合创建文章、更新、删除前选择目标。
- `notebook_search`：输入自然语言问题，在指定知识本内检索候选知识页面或片段。
- `notebook_list`：输入一个或多个已知 slug，精确读取页面正文。
- `notebook_article_list`：分页查看知识本里的原始文章来源，返回 articleId/title/url，不返回 Wiki 正文。

路由规则：
- 用户问"有哪些知识本/我能看哪些知识本/找知识本"：用 `notebook_readable_list`。
- 用户问"我能写哪些知识本/我要添加文章/修改知识本"：先用 `notebook_writable_list`，除非已给明确 `knowledgeBaseId`。
- 用户要"新建知识本"：用 `notebook_create`。
- 用户要"改名/改描述"：用 `notebook_update`。
- 用户要"把这篇链接/这段内容加入知识本"：用 `notebook_add_article`。
- 用户要"把这个文件/PDF/文档/表格/图片上传（加）到知识本"，或给出**本地文件路径**：先通过 `popo-cli popo notebook_add_file` 加载本 SKILL.md；如果没有 `knowledgeBaseId`，再用 `notebook_writable_list` 获取，最后执行 `scripts/add_file_to_notebook.py`（铁律 7）。
- 用户问"这个知识本里有哪些文章/来源"：用 `notebook_article_list`。
- 用户问"在某知识本里查/搜索/有没有关于……"：用 `notebook_search`。
- `notebook_search` 返回的正文中出现引用 slug，且需要展开阅读：提取 slug 后用 `notebook_list`。
- 用户直接给出 slug：用 `notebook_list`，不要先搜索。

---

## 添加本地文件到知识本

公开入口是 `popo-cli popo notebook_add_file` 路由；参数先传给路由，路由加载本 SKILL.md 后由模型执行脚本。脚本内部跑完「申请上传地址 → 直传存储 → 确认上传 → 入库」：

```bash
# macOS / Linux：files 是路由传给 Skill 的文件对象数组
cat > /tmp/popo_nb_files.json <<'JSON'
[{"path":"/docs/需求设计文档.pdf","title":"需求设计文档"}]
JSON
popo-cli popo notebook_add_file knowledgeBaseId=123456 files="@file:/tmp/popo_nb_files.json"

# 如果没有 knowledgeBaseId，省略该参数；Skill 先调用 notebook_writable_list 定位
popo-cli popo notebook_add_file files="@file:/tmp/popo_nb_files.json"
```

要点：
- `knowledgeBaseId` 可选；缺少时 Skill 先用 `notebook_writable_list` 获取，写操作必须基于可写知识本。
- `files` 必填，是对象数组：`path` 必填、`title` 可选（默认取文件名）；数量、类型和大小不在本地限制，以服务端实际返回为准。
- `files` 只作为路由上下文传给 Skill，不会直接传给后端文件接口。Skill 加载后将其转换为脚本的 `--kb-id/--file` 或 `--params-file` 参数。
- 脚本内部传给 popo-cli 的数组/字符串参数仍遵循 `@file:` / `@text:` 规则，Windows 下不手工拼 JSON。
  ```powershell
  $files = @(
      @{ path = "D:\docs\设计.pdf"; title = "需求设计文档" },
      @{ path = "D:\docs\纪要.docx" }
  )
  $tmp = Join-Path $env:TEMP "popo_nb_$([guid]::NewGuid().ToString('N')).json"
  try {
      [System.IO.File]::WriteAllText($tmp, (ConvertTo-Json $files -Depth 5 -Compress), [System.Text.UTF8Encoding]::new($false))
      popo-cli popo notebook_add_file knowledgeBaseId=123456 files="@file:$tmp"
  }
  finally {
      Remove-Item -Path $tmp -ErrorAction SilentlyContinue
  }
  ```
- 输出与其它 popo-cli 工具对齐：`status=1` 才成功，`data` 是数组，逐条展示 `articleId/title/url`。
- 失败时输出里的 `stage` 指明失败环节；同时把 `rawError` 交给模型理解，转换成用户可读的语义，不要把原始错误原样展示给用户。
- 如果服务端返回不支持文件类型、大小超限等错误，应根据实际错误内容告知用户具体原因；不要在 Skill 或脚本中预设固定白名单或限制。
- 参数、内部 popo-cli 子命令、错误 stage 全表见 [tool-reference.md](./references/tool-reference.md#本地文件上传脚本)。

---

## NEVER DO

- 不要使用 curl / python 直接调知识本接口，统一用 `popo-cli`（导出下载链接的下载除外）
- 不要猜测 `knowledgeBaseId` / `articleId` 等 ID，必须从接口获取或用户提供
- 不要用 `notebook_search` 传 slug，不要用 `notebook_list` 传自然语言 query，不要把 title 当 slug
- 不要跳过 tool-reference.md 直接拼命令（铁律 1/2）
- 删除知识本或删除文章前，除非用户明确要求删除具体 ID，必须先确认目标（铁律 5）
- 写操作返回 `status != 1` 时，读取 `message` 告知用户；必要时按错误提示调整参数重试一次，不要静默失败
- **不要在 Windows 平台用 `\"` 转义 JSON 数组/对象参数**（铁律 6）——必须走 `@file:`（Array/Object）或 `@text:`（含中文的 String）。ASCII 纯字符串可直传
- **不要把本地文件路径塞给 `notebook_add_article` 的 `url`**（铁律 7）——本地文件一律先走 `popo-cli popo notebook_add_file`，再由 Skill 执行 `scripts/add_file_to_notebook.py`

---

## 错误处理

- `popo-cli` 命令报错时查看错误信息，按需重试或报告给用户（不暴露内部细节）
- 统一响应 `status=1` 才成功；只有成功响应才读取 `data`；失败时读取 `message` 或错误信息并告知用户
- 认证失败（401/403）→ 检查环境变量 `uid` / fabric 登录状态
- 文件上传脚本调用的 `notebook_file_upload_url` / `notebook_file_confirm` / `notebook_add_attachment` 未注册 → 说明当前 popo-cli 版本尚未支持文件上传，需要先升级/补齐这 3 个 notebook 子工具，不要让脚本改为直连 notebook HTTP；`notebook_add_file` 本身只需作为 Skill 路由入口，不需要注册为 Fabric 业务工具
- 类型解析错误（`Cannot construct instance of ArrayList`、`JSON parse error`）→ 按平台分叉（铁律 6）：
  - **Windows**：**禁止** HTTP 直传兜底（同样受 PowerShell 引号问题影响），**必须**用 `@file:` 临时文件重试
  - **macOS/Linux**：检查 `\"` 转义是否正确，或改用 HTTP 直传
 - 文件上传脚本失败：读取 `stage`、`message` 和 `rawError`，先理解实际错误再向用户解释，**不要原样倾倒 rawError**；不要凭固定规则猜测错误。

## 详细参考

- [references/tool-reference.md](./references/tool-reference.md) — 11 个 tool 全部参数、返回值与跨平台示例，以及文件上传脚本和其内部 3 个 popo-cli 子工具说明
