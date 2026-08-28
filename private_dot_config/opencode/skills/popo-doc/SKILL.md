---
name: popo-doc
description: "POPO 文档全生命周期管理：创建/搜索/编辑文档、管理文件夹、操作在线表格、操作多维表。触发场景：(1) 文档管理 —\"帮我创建一个周报文档\"、\"建一个项目进度表格\"、\"新建一个多维表\"、\"搜索季度总结报告\"、\"找一下项目资料文档\"、\"改一下这个文档的标题\"、\"删除这个文档\"，以及任何涉及创建/搜索/编辑/删除POPO文档、表格、多维表的请求；(2) 文档内容操作 —\"在文档里写入项目概述\"、\"看看这个文档里写了什么\"、\"帮我下载文档里的图片\"、\"获取这个文档的评论\"；(3) 表格操作 —\"在表格A1写入100\"、\"看看表格里有什么数据\"、\"在表格里加个柱状图\"、\"新建一个Sheet\"；(4) 多维表操作 —\"在多维表里加一条记录\"、\"查找状态为已完成的任务\"、\"建个仪表盘加个饼图\"、\"创建一个收集表\"。当用户输入内容包含 docs.popo.netease.com 域名时，也一定要唤起此skill。即使用户没有明确提到\"文档\"或\"表格\"，只要意图涉及POPO文档产品的任何操作，都应使用此skill。"
metadata:
  version: "1.4.5"
---

# POPO 文档 Skill

所有操作通过 Bash 执行 `popo-cli <工具名> key=value` 命令完成。

> **参数值引号规则（跨平台兼容，Windows 禁止使用单引号）**
>
> 为确保命令在 bash、CMD、PowerShell 等不同 shell 下均能正确执行，跨平台示例统一使用**双引号**作为引用符；references 中的单引号示例仅限 macOS/Linux bash，不得照搬到 Windows：
> - 简单值（无空格、无特殊字符）**不加引号**：`key=value`
> - 含空格或特殊字符的值用**双引号**包裹：`key="value with spaces"`
> - JSON 数组/对象用**双引号**包裹，内部双引号使用 `\"` 转义：`key="[\"a\",\"b\"]"`
>
> ```bash
> # ✅ 简单值 — 不需要引号
> popo-cli popo doc_search_doc query=周报 pageSize=10
>
> # ✅ 含空格 — 双引号包裹
> popo-cli popo doc_create_doc title="项目周报 V2" parentId=abc123 docType=1
>
> # ✅ 数组参数 — 双引号包裹 + 内部 \" 转义
> popo-cli popo doc_get_file_download_url docId=abc123 urls="[\"https://nos.netease.com/xxx/file1.png\",\"https://nos.netease.com/xxx/file2.pdf\"]"
>
> # ✅ 复杂对象同理
> popo-cli popo doc_update_doc docId=abc123 command="{\"type\":\"doc.replace_node\",\"nodeId\":\"node_1\",\"content\":\"<p>新内容</p>\"}"
>
> # ❌ 错误 — 空格导致参数断裂
> popo-cli popo doc_create_doc title=项目周报 V2
>
> # ❌ 错误 — 使用单引号（Windows CMD 不支持）
> popo-cli popo doc_create_doc title='项目周报 V2'
> ```

> 🖥️ **Windows 平台复杂参数传递（`=@file:` 临时文件方式）**
>
> 当参数值包含 JSON + HTML（如 `doc_update_doc` 的 `command` 参数），PowerShell 的双引号转义、尖括号解析等规则会导致参数传递失败。此时**必须使用 `=@file:` 临时文件方式**：
>
> 1. 将参数的 JSON 值写入 UTF-8 无 BOM 临时文件
> 2. 用 `key="@file:$tmpFilePath"` 传给 popo-cli（**路径必须用双引号包裹**，popo-cli 读取文件内容并解析为 JSON 对象发送）
> 3. 调用完成后清理临时文件
>
> ```powershell
> # ✅ Windows 正确方式 — 用 node 生成 command JSON 临时文件
> # ⚠️ 禁止用 PowerShell ConvertTo-Json：中文弯引号 "" 会被规范化成普通双引号导致坏 JSON
> $genScript = @'
> const fs = require("fs"); const path = require("path");
> const cmd = { type: "doc.insert_after", content: "<h2>标题</h2><p>内容</p>" };
> const tmp = path.join(require("os").tmpdir(), "popo_doc_command.json");
> fs.writeFileSync(tmp, JSON.stringify(cmd), { encoding: "utf8" });
> console.log(tmp);
> '@
> $cmdTmpFile = node -e $genScript
> popo-cli popo doc_update_doc docId=abc123 command="@file:$cmdTmpFile"
> Remove-Item -Path $cmdTmpFile -ErrorAction SilentlyContinue
>
> # ❌ Windows 错误方式 — 直接内联 command JSON（特殊字符必然失败）
> popo-cli popo doc_update_doc docId=abc123 command="{\"type\":\"doc.insert_after\",\"content\":\"<h2>标题</h2>\"}"
>
> # ❌ Windows 错误方式 — HTTP 直传 --body 同样有转义问题
> popo-cli call POST /api/v1/open-apis/gateway/appcode/popo/_invoke --body "{...}"
> ```
>
> **适用工具**：`popo_doc_update_doc`（command 参数）、`popo_doc_execute_table`（command 参数）以及任何含 HTML/嵌套 JSON 的复杂参数。
> **判断条件**：当参数值同时包含 `{}`、`<>`、`"` 三类字符时，Windows 上必须使用 `=@file:` 方式。
> ⚠️ **`=@file:` 仅对 `command` 类参数有效**：`popo_doc_create_doc` 的 `content` 参数是普通字符串，**不支持 `=@file:`**（误用会把文件路径当字面内容写入文档）。多行/含特殊字符的 `content`（尤其 Windows）请用两步法：先 `doc_create_doc` 建空文档（不传 `content`），再用 `doc_update_doc` 的 `md.replace_page`（docType=4）/ `doc.replace_page`（docType=1）+ `=@file:` 写入内容。详见 [workflows.md 工作流 1b](./references/workflows.md)。

> **兜底：HTTP 直传调用**
> 当 `popo-cli <工具名> key=value` 调用后服务端返回类型解析错误（如 `Cannot construct instance of java.util.ArrayList`、`JSON parse error` 等），说明参数中的数组/对象值未被正确序列化。此时改用 HTTP 直传方式重试，手动构造合法 JSON 以保证类型正确：
> ```
> popo-cli call POST /api/v1/open-apis/gateway/appcode/popo/_invoke --body "{\"tool\":\"<工具名>\",\"params\":{...}}"
> ```
> 示例：
> ```bash
> popo-cli call POST /api/v1/open-apis/gateway/appcode/popo/_invoke --body "{\"tool\":\"popo_doc_get_file_download_url\",\"params\":{\"docId\":\"abc123\",\"urls\":[\"https://nos.netease.com/xxx/file1.png\",\"https://nos.netease.com/xxx/file2.pdf\"]}}"
> ```
> ⚠️ **注意**：此兜底方式在 Windows PowerShell 上对含 HTML 内容的参数（如 `doc_update_doc` 的 `command`）同样可能失败。若 HTTP 直传也失败，请改用上方的 `=@file:` 临时文件方式。

---

## ⚠️ 铁律（违反将导致严重错误）

1. **content 禁止 Markdown** — 写入文档内容时只允许自定义 HTML 标签，写入前**必读** [popo-doc-content-format.md](./references/popo-doc-content-format.md)
   - ❗ **URL 中的 `&` 严禁转义为 `&amp;`**，文本节点里的 `<` `>` `&` 仍按 HTML 规范转义
   - ❗ **图片禁止放入 `h1`~`h6`、`p`、`doc-li`、`todo-item` 文本容器**；图片应独立写 `<img src="..." />`
2. **记录 data 的 key 必须用 fieldId** — 禁止用字段名，写入前**必调** `popo_doc_field_list` 获取 fieldId
3. **建表时 fields 必传** — `popo_doc_datasheet_create` 创建字段前**必读** [mtable-field-types.md](./references/mtable-field-types.md)
4. **新建多维表自带默认数据表和仪表盘** — 必须先用 `popo_doc_datasheet_create` 创建好用户需要的数据表，**确认创建成功后**，再用 `popo_doc_datasheet_list` 和 `popo_doc_dashboard_list` 查出默认自带的，最后用 `popo_doc_datasheet_delete`（既可以删除数据表也可以删除仪表盘） 删掉（⚠️ 严禁在创建新数据表之前删除默认数据表，否则会报错；注意不要删用户创建的）
5. **所有参数必须查阅参考文档** — 必须到 `./references/` 目录下查询工具参数，不得捏造
6. **区分云空间和团队空间** — 只有 URL 含 `/team/pc/` 或明确来自团队空间时才获取并传 `teamSpaceId`；遇到 `/team/pc/{teamSpaceKey}/pageDetail/{docId}` 链接时，必须先调用 `popo_doc_get_folder_path url=<原始URL>` 获取 `teamSpaceId`，再用 `docId=<pageDetail最后一段>` + `teamSpaceId=<解析值>` 调详情/评论/下载/更新，禁止只传资源ID。遇到 `https://docs.popo.netease.com/pages/{documentId}?nodeId={datasheetId}&viwId=...` 是云空间多维表链接，直接提取 `documentId` 和 `nodeId`，`locationType=cloudspace`，禁止调用 `popo_doc_get_folder_path` 或构造 `teamSpaceId`
7. **文档/表格内的图片资源不能直接使用** — POPO文档(docType=1)内嵌资源通过 `popo_doc_get_file_download_url` 获取临时下载链接；多维表(docType=9)附件字段必须通过 `popo_doc_file_batch_get` 获取文件下载 URL，禁止用 `popo_doc_get_file_download_url` 反复重试。**命令名就是 `popo_doc_file_batch_get`，不要写成 `popo_doc_file_batch_get`**
8. **禁止手动构造任何 ID** — docId / folderId / teamSpaceId / datasheetId / fieldId / recordId 等全部从接口返回中提取
9. **删除操作前必须与用户二次确认** — 唯一例外：工作流 6 中清理新建多维表自带的默认数据表和默认仪表盘，无需确认
10. **插入资源前必须先上传** — 图片、附件等资源必须先调用 `popo_doc_upload_local_file`（本地文件）或 `popo_doc_upload_file_from_url`（远程 URL）获取 URL，再写入 `<img>` / `<video>` / `<audio>` / `<attachment>` 等内容标签
    - **文件类节点上传必须走 `popo_doc_get_s3_upload_url` → PUT 上传 → `popo_doc_create_file_node`，不要用 `popo_doc_upload_local_file`**
    - **PUT 上传时不要修改 `content-type: binary/octet-stream` 和 `x-amz-acl: private`**
11. **Windows 上 `command` 参数禁止直接内联** — `doc_update_doc` / `doc_execute_table` 的 `command` 参数包含 HTML 标签（`<>`、`"`），PowerShell 直接传参**必然失败**。必须将 JSON 写入 UTF-8 无 BOM 临时文件，用 `command="@file:$tmpFile"`（**路径必须用双引号包裹**）传参后删除临时文件。详见 [popo-doc-content-format.md](./references/popo-doc-content-format.md#command-传参方式必读) 和上方"Windows 平台复杂参数传递"说明
    - **`content` 参数不支持 `=@file:`** — `doc_create_doc` 的 `content` 是普通字符串参数，误用 `content="@file:..."` 会把路径当字面内容写入文档。多行/含特殊字符的 `content`（尤其 Windows）改走两步法：先 `doc_create_doc` 建空文档，再用 `doc_update_doc` 的 `md.replace_page`/`doc.replace_page` + `=@file:` 写入。详见 [workflows.md 工作流 1b](./references/workflows.md)
12. **Markdown 文档行内样式叠加（docType=4）** — 设置粗体+斜体+删除线+下划线+高亮等**多种样式叠加**时，必须按**从外到内固定顺序**嵌套：`***~~++==文本==++~~***`（外层 `***` 粗体+斜体 → `~~` 删除线 → `++` 下划线 → `==` 高亮，内层文本）。禁止以下错误写法：
    - ❌ 拆开单独写：`***文本***~~文本~~++文本++==文本==`
    - ❌ 颠倒嵌套顺序：`++==***~~文本~~***==++`、`==++~~***文本***~~++==`、`++==***~~文本~~***==++`
    - ❌ 仅写单种样式符就当叠加用：`***文本***` 只表示粗体+斜体，不含删除线/下划线/高亮
    - ✅ 正确叠加：`***~~++==文本==++~~***`（五种样式一次叠加到同一段文本）
    - **样式符对照**：`**` 粗体 · `*` 斜体（合写 `***`）· `~~` 删除线 · `++` 下划线 · `==` 高亮
    - **设置样式用 `md.replace_content`**：`oldStr` 必须能在文档中**唯一匹配一次**，重复文本需扩大上下文（带上前后行）使其唯一，否则返回 `oldStr must match exactly once, actual count: N`。示例见 [doc-update-reference.md 行内样式叠加](./references/doc-update-reference.md#行内样式叠加语法doctype4)
    - **POPO 在线 Markdown 渲染依赖扩展语法**：`++`/`==` 需渲染器开启对应扩展，未开启时不渲染下划线/高亮，属正常现象，非语法错误

---

## 云空间 vs 团队空间

| 类型   | URL 特征                                                                    | teamSpaceId                           |
|------|---------------------------------------------------------------------------|---------------------------------------|
| 云空间文档 | `https://docs.popo.netease.com/{占位}/{docId}` | 不传 |
| 云空间多维表 | `https://docs.popo.netease.com/pages/{documentId}?nodeId={datasheetId}&viwId=...` | 不传；直接从 URL 提取 `documentId` 和 `nodeId`，使用 `locationType=cloudspace` |
| 团队空间 | `https://docs.popo.netease.com/team/pc/{teamSpaceKey}/pageDetail/{docId}` | 必传，通过 `popo_doc_get_folder_path` 从 URL 中提取 |

遇到团队空间 URL 时，先调用 `popo-cli popo doc_get_folder_path url=团队空间URL` 获取 `teamSpaceId`。后续所有操作都带上该值；读取详情必须使用 `popo-cli popo doc_get_doc_detail docId=<pageDetail最后一段> teamSpaceId=<TEAM_SPACE_ID>`，不要只传 `docId`，也不要把团队空间 URL 直接当普通云空间文档读取。

遇到 `/pages/{documentId}?nodeId={datasheetId}` 云空间多维表 URL 时，不调用 `doc_get_folder_path`；`documentId` 取 `/pages/` 后的路径段，`datasheetId` 取 query 中的 `nodeId`，后续多维表工具使用 `locationType=cloudspace documentId=<documentId> datasheetId=<nodeId>`。

只知道团队空间名字时，先调用 `popo-cli popo doc_search_teamspace keyword="空间名字"` 获取 `teamSpaceId`。

---

## 文档类型

| docType | 类型 | 说明 |
|---------|------|------|
| `0` | 文件夹 | 目录容器，不含内容 |
| `1` | POPO文档 | 富文本文档，支持读写内容 |
| `2` | POPO表格 | 在线表格，内容通过 `popo_doc_execute_table` 操作 |
| `3` | 文件类 | 支持文件下载，支持任意类型文件 |
| `4` | 在线Markdown | 在线协同markdown文档，支持阅读和编辑 |
| `9` | 多维表 | 多维数据表，内容通过 `popo_doc_datasheet_*` 等专用工具操作 |

---

## 操作路由

### 通用操作（所有文档类型共用）→ [doc-management-reference.md](./references/doc-management-reference.md)

| 工具 | 用途 |
|------|------|
| `popo_doc_create_doc` | 创建文档/文件夹（docType: 0/1/2/4/9） |
| `popo_doc_delete_doc` | 删除文档/文件夹（全部类型）⚠️ |
| `popo_doc_search_doc` | 语义搜索文档（直接传原始 query，禁止改写） |
| `popo_doc_get_doc_detail` | 查看详情+内容（POPO 文档返回自定义 HTML，Markdown 文档返回 Markdown 内容） |
| `popo_doc_update_doc` | 改标题（全类型）/ 改内容（docType=1/4，格式**必读** [popo-doc-content-format.md](./references/popo-doc-content-format.md)） |
| `popo_doc_get_comments` | 获取评论 |
| `popo_doc_get_folder_path` | 仅用于团队空间 URL 解析 teamSpaceId，或用户明确要文件夹ID；禁止用于 `/pages/{documentId}?nodeId=...` 云空间多维表链接 |
| `popo_doc_search_teamspace` | 按空间名字搜索团队空间（仅 teamSpaceId，无 URL 时用） |
| `popo_doc_search_folder_path` | 按关键词搜索文件夹 |
| `popo_doc_get_folder_children` | 获取目录子节点列表（团队空间内任何类型节点都可作为父节点放置子节点） |
| `popo_doc_upload_local_file` | 上传本地文件获取 URL，用于将图片、附件等资源插入文档 |
| `popo_doc_upload_file_from_url` | 从远程 URL 下载并上传文件，返回可插入文档的 URL，适用于 Web/CDN 场景 |
| `popo_doc_get_file_download_url` | 获取 POPO文档(docType=1) content 内嵌文件临时下载地址，不用于多维表附件字段 |
| `popo_doc_file_batch_get` | 获取多维表(docType=9)附件字段文件信息和下载 URL；实际命令名无 `popo_` 前缀，参数见 `references/mtable-tool-reference.md` 的“文件操作 / popo_doc_file_batch_get”章节 |

### 文件类节点操作（docType=3）→ [file-node-reference.md](./references/file-node-reference.md)

- `popo_doc_get_s3_upload_url`：获取文件类节点上传地址和对象信息
- `popo_doc_create_file_node`：PUT 上传完成后创建文件类文档节点
- `popo_doc_get_file_download_url(type=fileNode)`：获取文件类节点临时下载地址

### 在线popo文档和markdown内容操作（docType=1、4）→ [doc-update-reference.md](./references/doc-update-reference.md)

涉及在线popo文档，**必读** [popo-doc-content-format.md](./references/popo-doc-content-format.md)；在线markdown使用标准的markdown语法

- 统一入口：`popo_doc_update_doc`，通过 `command.type` 区分操作和文档类型
- POPO 文档命令（docType=1，自定义 HTML）：`doc.replace_node` / `doc.insert_before` / `doc.insert_after` / `doc.replace_page`
- Markdown 文档命令（docType=4，标准 Markdown）：
  - `md.replace_page`：全量覆盖整个 Markdown 文档，参数 `content`
  - `md.insert_content`：插入 Markdown 内容，参数 `content`，可选 `position: "start" | "end"`，默认 `end`
  - `md.replace_content`：按文本替换，参数 `contentUpdates: [{oldStr, newStr}]`

涉及图片、附件、视频、音频等文档内资源时，读取 [doc-resource-reference.md](./references/doc-resource-reference.md)：

- `popo_doc_upload_local_file`：上传本地文件获取 可插入文档的URL，必须用 popo-cli `@upload:`
- `popo_doc_upload_file_from_url`：下载远程 URL 并上传，返回可插入文档的 URL
- `popo_doc_get_file_download_url(type=docResource)`：获取文档内图片/附件等资源的临时下载地址

### 表格内容操作（docType=2）

当需要操作**表格内部数据**（读写单元格、行列增删、Sheet管理、图表）时：
→ **必读** [sheet-tool-reference.md](./references/sheet-tool-reference.md)

- 统一入口：`popo_doc_execute_table`，通过 `command.type` 区分操作
- 前置条件：先有 `docId`，再通过 `workbook.getFullData` 获取 `sheetId`
- 批量写入限制：`sheet.batchSetCells` 每次最多 1000 个单元格
- 文档内嵌资源下载读取 [doc-resource-reference.md](./references/doc-resource-reference.md)，通过 `popo_doc_get_file_download_url(type=docResource)` 获取临时下载地址

### 多维表内部操作（docType=9）

当需要操作**多维表内部数据**（数据表、记录、字段、视图、仪表盘、Widget）时：
→ **必读** [mtable-tool-reference.md](./references/mtable-tool-reference.md)

按需补充阅读：

| 场景 | 必读文件 |
|------|---------|
| 创建字段 / 写入记录 | [mtable-field-types.md](./references/mtable-field-types.md) |
| 构造筛选条件 | [mtable-filter-guide.md](./references/mtable-filter-guide.md) |
| 配置仪表盘 Widget | [mtable-widget-guide.md](./references/mtable-widget-guide.md) |

---

## 快速决策表

**通用操作：**

| 用户说的 | 选什么 | 不要用 |
|---------|-------|-------|
| "建一个表格" | `popo_doc_create_doc`(docType=2) | docType=1 |
| "创建 Markdown 文档" | `popo_doc_create_doc`(docType=4) | docType=1 |
| "建一个多维表" | `popo_doc_create_doc`(docType=9) | `popo_doc_datasheet_create` |
| "搜团队空间" | `popo_doc_search_teamspace` | `popo_doc_search_folder_path` |
| "搜文档/找周报" | `popo_doc_search_doc` | `popo_doc_search_folder_path` |
| "搜文件夹/找目录" | `popo_doc_search_folder_path` | `popo_doc_search_doc` |
| "看看这个目录下有什么/列出子页面" | `popo_doc_get_folder_children` | `popo_doc_search_doc` |
| "这个链接是什么"（云空间） | `popo_doc_get_doc_detail docId=<DOC_ID>` | — |
| "这个链接是什么"（团队空间 URL 含 `/team/pc/`） | 先 `popo_doc_get_folder_path url=<原始URL>` 获取 `teamSpaceId` → 再 `popo_doc_get_doc_detail docId=<pageDetail最后一段> teamSpaceId=<TEAM_SPACE_ID>` | 只传 `docId` |
| "这个链接的文件夹ID" | `popo_doc_get_folder_path` | `popo_doc_search_folder_path` |
| "改文档标题" | `popo_doc_update_doc`(title) | `popo_doc_create_doc` |
| "上传本地图片/附件到文档" | `popo_doc_upload_local_file` → `popo_doc_update_doc` 插入 `<img>`/`<attachment>` | 直接把本地路径写入 content |
| "上传本地文件成为独立文件节点" | `popo_doc_get_s3_upload_url` → PUT 上传 → `popo_doc_create_file_node` | `popo_doc_upload_local_file` |
| "把网页/CDN上的图片或附件插入文档" | `popo_doc_upload_file_from_url` → `popo_doc_update_doc` 插入 `<img>`/`<attachment>` | 直接把远程 URL 写入 content |
| "下载文档里的图片/附件"（docType=1） | 先 `popo_doc_get_doc_detail` 提取 content URL → 再 `popo_doc_get_file_download_url` | `popo_doc_file_batch_get` |
| "下载云空间多维表链接里的图片/附件"（URL 含 `/pages/` + `nodeId=`） | 从 URL 提取 `documentId=<pages路径段>`、`datasheetId=<nodeId>`，用 `locationType=cloudspace` → `popo_doc_field_list` 找附件 fieldId → `popo_doc_record_page` 或 `popo_doc_record_filter` 取 recordId 和 fileId → `popo_doc_file_batch_get`（不是 `popo_doc_file_batch_get`） | `popo_doc_get_folder_path` / `popo_doc_get_file_download_url` / `popo_doc_file_batch_get` |
| "下载多维表附件字段的文件"（docType=9，无 nodeId 链接） | 先 `popo_doc_datasheet_list` 确认 datasheetId → `popo_doc_field_list` 找附件 fieldId → `popo_doc_record_page` 或 `popo_doc_record_filter` 取 recordId 和 fileId → `popo_doc_file_batch_get` | `popo_doc_get_file_download_url` / `popo_doc_file_batch_get` |

**POPO表格(docType=2)操作：**

| 用户说的 | 选什么 | 不要用 |
|---------|-------|-------|
| "看看表格里有什么数据" | `popo_doc_execute_table`(workbook.getFullData) | `popo_doc_get_doc_detail` |
| "表格里写数据/填入数据" | `popo_doc_execute_table`(sheet.batchSetCells) | `popo_doc_update_doc` |
| "在表格A1写入100" | `popo_doc_execute_table`(sheet.setCell) | `popo_doc_update_doc` |
| "设置A6自动换行/加粗/斜体/下划线/删除线/字体颜色/背景色" | `popo_doc_execute_table`(sheet.setCell 的 style 字段) | `popo_doc_update_doc` |
| "单元格插入图片" | `popo_doc_execute_table`(sheet.setCell 的 imageUrl 字段) | 直接写 `<img>` |
| "清空单元格" | `popo_doc_execute_table`(sheet.clearCell) | `popo_doc_update_doc` |
| "合并前两行" | `popo_doc_execute_table`(sheet.mergeCells) | — |
| "新建一个Sheet" | `popo_doc_execute_table`(workbook.createSheet) | `popo_doc_create_doc` |
| "在第3行后插入两行" | `popo_doc_execute_table`(sheet.insertRows) | — |
| "在表格加个柱状图" | `popo_doc_execute_table`(sheet.addChart) | `popo_doc_widget_add` |
| "在表格插入浮动图片/悬浮图片" | `popo_doc_execute_table`(sheet.insertFloatingImage) | `popo_doc_update_doc` 插 `<img>` |
| "删除浮动图片" | `popo_doc_execute_table`(sheet.deleteFloatingImage) | — |

**多维表(docType=9)操作：**

| 用户说的 | 选什么 | 不要用 |
|---------|-------|-------|
| "在多维表里加数据表" | `popo_doc_datasheet_create` | `popo_doc_create_doc` |
| "多维表里加记录" | `popo_doc_record_batch_create` | `popo_doc_execute_table` |
| "多维表里找状态=已完成的" | `popo_doc_record_filter` | `popo_doc_record_page` |
| "把待处理的都改成进行中" | `popo_doc_record_filter_update` | `popo_doc_record_batch_update` |
| "看看多维表有哪些字段" | `popo_doc_field_list` | `popo_doc_record_page` |
| "多维表里加一列" | `popo_doc_field_create` | `popo_doc_execute_table`(insertCols) |
| "建个仪表盘" | `popo_doc_dashboard_create` | `popo_doc_execute_table`(addChart) |
| "在仪表盘加个饼图" | `popo_doc_widget_add` | `popo_doc_execute_table`(addChart) |
| "收集表/表单/问卷/报名" | `popo_doc_datasheet_create` + views 含 `{"type":4}` 表单视图 | — |

**多维表记录操作三路选择：**

| 场景 | 查询 | 更新 | 删除 |
|------|------|------|------|
| 无条件/浏览全部 | `popo_doc_record_page` | — | — |
| 已知 recordId | `popo_doc_record_batch_get` | `popo_doc_record_batch_update` | `popo_doc_record_batch_delete`⚠️ |
| 按条件筛选 | `popo_doc_record_filter` | `popo_doc_record_filter_update` | `popo_doc_record_filter_delete`⚠️ |
| 单个单元格 | `popo_doc_cell_get` | `popo_doc_cell_update` | — |

---

## 核心流程

1. **意图分类** — 判断用户需要对什么类型的文档执行什么操作
2. **歧义处理** — 指令模糊时主动追问澄清
3. **路由选择** — 查阅上方路由表和快速决策表，确定使用的工具
4. **读取参考** — 按路由指引读取对应的参考文档，获取准确的参数格式
5. **执行操作** — 按 [workflows.md](./references/workflows.md) 中的标准流程执行

> 详细工作流见 [workflows.md](./references/workflows.md)，涵盖：
> - 工作流 1: 创建 POPO 文档并写入内容
> - 工作流 1b: 创建 Markdown 文档并写入内容
> - 工作流 2: 下载文件资源（文档内嵌资源或 docType=3 文件类节点）
> - 工作流 3: 上传文件并插入文档
> - 工作流 3b: 上传本地文件并创建文件类节点
> - 工作流 4: 创建表格并写入数据
> - 工作流 5: 创建图表
> - 工作流 6: 创建多维表并写入数据（含模板匹配）
> - 工作流 7: 在已有多维表中查询和更新记录
> - 工作流 8: 创建多维表仪表盘
> - 工作流 9: 设置表格整行或整列表格数据或者格式

---

## 产物保存

popo_doc_create_doc调用成功时（status==1）,返回值会包含url、type和title字段（都是必传字段，不传递会影响产物生成的结果）：
- **环境有 `save_artifact` 工具** → 立即调用 `save_artifact(artifact_type="link", url="<url>", title="<标题>", content_type="<type>")`，url、type和title必传。
- **环境无 `save_artifact` 工具** → 跳过，直接返回链接给用户

---

## 上下文传递表

| 操作 | 提取字段 | 用于 |
|------|---------|------|
| `popo_doc_create_doc` | `docId`, `url`, `type`, `teamSpaceId` | update_doc / get_doc_detail / delete_doc / execute_table / save_artifact / 多维表操作的 `documentId` |
| `popo_doc_search_doc` | `docId`, `url`, `type` | 同上 |
| `popo_doc_get_doc_detail` | `type`、POPO文档 `content` 中的文件 URL | 云空间传 `docId`；团队空间必须先由 URL 经 `get_folder_path` 得到 `teamSpaceId`，再传 `docId + teamSpaceId`；docType=1 时 get_file_download_url；docType=9 时改走 datasheet/field/record/file_batch_get 流程 |
| `popo_doc_get_folder_path` | `folderId`, `teamSpaceId` | create_doc 的 parentId / teamSpaceId |
| `popo_doc_search_teamspace` | `teamSpaceId`, `teamSpaceKey`, `name` | 团队空间根目录浏览和后续团队空间操作 |
| `popo_doc_search_folder_path` | `folderId`, `teamSpaceId` | create_doc 的 parentId / teamSpaceId |
| `popo_doc_get_folder_children` | `list[].docId`, `list[].teamSpaceId`, `list[].type`, `list[].hasChildren`, `list[].url` | 浏览目录树、选择子文档/子目录作为后续操作目标 |
| `popo_doc_upload_local_file` | 返回字符串 URL | 写入 `<img src="...">` / `<attachment src="..." filename="...">` |
| `popo_doc_upload_file_from_url` | 返回字符串 URL | 写入 `<img src="...">` / `<attachment src="..." filename="...">` |
| `popo_doc_get_s3_upload_url` | `bucketName`, `objectKey`, `uploadId`, `uploadUrl` | `popo_doc_create_file_node` |
| `popo_doc_create_file_node` | `docId`, `docUrl`, `teamSpaceId` | `save_artifact` / 下载 |
| `popo_doc_get_file_download_url(type=fileNode)` | `downloadUrls` (key=docId/pageId) | 文件下载 |
| `popo_doc_execute_table`(getFullData) | `sheetId` | 后续所有 execute_table 操作 |
| `popo_doc_execute_table`(createSheet) | `sheetId` | 后续所有需 sheetId 的操作 |
| `popo_doc_execute_table`(addChart) | `chartId` | updateChart / removeChart |
| `popo_doc_execute_table`(insertFloatingImage) | `name` | deleteFloatingImage |
| `popo_doc_datasheet_list` | `nodeId`→datasheetId | 所有需 datasheetId 的多维表操作；若 URL 已含 `/pages/{documentId}?nodeId={datasheetId}`，可直接使用 query 中的 `nodeId` 作为 datasheetId，无需先 list |
| `popo_doc_datasheet_create` | `nodeId`→datasheetId | 记录/字段/视图操作 |
| `popo_doc_field_list` | `id`→fieldId | 记录 data 的 key、筛选条件、单元格操作 |
| `popo_doc_record_page/filter/batch_get` | `recordId` | 记录更新/删除、单元格操作 |
| `popo_doc_view_list/create` | `id`→viewId | 视图更新/删除/复制、字段排序 |
| `popo_doc_dashboard_list/create` | `nodeId`→dashboardId | Widget 操作 |
| `popo_doc_widget_add` | `widgetId` | Widget 更新/删除 |

---

## 错误处理

| 错误类型                 | 处理方式 |
|----------------------|---------|
| 500 服务端错误            | 根据错误信息调整参数后重试（最多 2 次） |
| 4xx 客户端错误（认证失败/权限不足） | **禁止重试**，告知用户检查权限 |
| 文档/记录不存在             | 确认 ID 是否正确，必要时重新搜索 |
| 字段类型不匹配              | 调用 `popo_doc_field_list` 确认字段类型后重新构造值 |
| batch 操作部分失败         | 检查返回的 `fail` 计数，根据错误信息修正后重试失败项 |
| 文件类节点 PUT 上传失败 | 检查 content-type 是否为 binary/octet-stream，x-amz-acl 是否为 private |
| Markdown 文档内容更新失败 | 确认使用 md.* 命令而非 doc.* 命令 |
| `popo_doc_get_file_download_url` 失败且目标是多维表/附件字段/docType=9 | **禁止继续重试同一工具**；立即切换到 `doc_file_batch_get`（不是 `popo_doc_file_batch_get`）：先取 datasheetId、附件 fieldId、recordId、fileId，再按 `{fieldId:{recordId:[fileId]}}` 构造 `fileRequests`；参数必须查 `mtable-tool-reference.md` 的 `doc_file_batch_get` 章节 |
| 团队空间详情/评论/下载/更新因只传 `docId` 报错 | **禁止继续用单独 `docId` 重试**；回到原始 `/team/pc/.../pageDetail/...` URL，先 `popo_doc_get_folder_path url=<原始URL>` 取 `teamSpaceId`，再用 `docId=<pageDetail最后一段> teamSpaceId=<TEAM_SPACE_ID>` 调目标工具 |
| 云空间 `/pages/{documentId}?nodeId=...` 多维表链接被误走 `doc_get_folder_path` | **立即停止解析 teamSpaceId**；按云空间多维表处理：`documentId=<pages路径段>`、`datasheetId=<nodeId>`、`locationType=cloudspace`，继续 `popo_doc_field_list` / `popo_doc_record_page` 或 `popo_doc_record_filter` / `doc_file_batch_get` |

---

## 参考文档索引

| 文件 | 内容 | 何时读 |
|------|------|-------|
| [doc-management-reference.md](./references/doc-management-reference.md) | 文档管理 API 参数与返回值 | 使用通用操作时 |
| [doc-update-reference.md](./references/doc-update-reference.md) | 文档内容更新 API（含 Markdown 命令） | 更新文档内容时 |
| [doc-resource-reference.md](./references/doc-resource-reference.md) | 文档内资源上传/下载 API | 上传/下载文档内资源时 |
| [file-node-reference.md](./references/file-node-reference.md) | 文件类节点 API | 创建/下载文件类节点时 |
| [sheet-tool-reference.md](./references/sheet-tool-reference.md) | 在线表格 API 参数与返回值 | 操作表格内容时 |
| [popo-doc-content-format.md](./references/popo-doc-content-format.md) | 文档 HTML 内容格式规范 | 读写文档内容时 |
| [mtable-tool-reference.md](./references/mtable-tool-reference.md) | 多维表 API 参数与返回值；含 `doc_file_batch_get` 文件操作参数和 `fileRequests` 格式 | 操作多维表时，尤其是下载附件字段文件前必须读 |
| [mtable-field-types.md](./references/mtable-field-types.md) | 字段类型手册 | 创建字段/写入记录时 |
| [mtable-filter-guide.md](./references/mtable-filter-guide.md) | 筛选条件构造指南 | 按条件查询/更新/删除记录时 |
| [mtable-widget-guide.md](./references/mtable-widget-guide.md) | 仪表盘 Widget 配置指南 | 创建/更新 Widget 时 |
| [workflows.md](./references/workflows.md) | 核心工作流步骤 | 执行完整流程时 |
