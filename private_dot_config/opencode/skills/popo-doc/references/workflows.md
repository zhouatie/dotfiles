# 核心工作流

本文件只放多步骤、跨工具、顺序敏感或高风险任务的流程。执行任何工作流时，仍需遵守 [SKILL.md](../SKILL.md) 顶部的强制规范。

> 团队空间统一规则：只有目标 URL 含 `/team/pc/` 或明确来自团队空间时，才先用 `popo_doc_get_folder_path url=<原始URL>` 获取 `teamSpaceId`。
> 云空间多维表 URL 规则：`https://docs.popo.netease.com/pages/{documentId}?nodeId={datasheetId}&viwId=...` 不需要也禁止解析 `teamSpaceId`；直接使用 `locationType=cloudspace documentId=<pages路径段> datasheetId=<nodeId>`。

---

## 工作流 1: 创建 POPO 文档并写入内容

适用：需要新建 docType=1 文档并写入初始内容。

> ⚠️ **`content` 参数是普通字符串，不支持 `=@file:` 语法**。多行/含 HTML 标签的初始内容在 Windows 上直接内联极易失败（`<>`、`"` 被 PowerShell 截断）。**推荐两步法**：先建空文档（不传 `content`），再用 `doc_update_doc` 的 `doc.replace_page` + `=@file:` 写入内容（`command` 参数才支持 `=@file:`）。

> ⚠️ **`doc.replace_page` 必须用 `<doc>` 根节点包裹**：全量替换时 `content` 须为单一 `<doc>` 根节点，所有块级标签包在 `<doc>...</doc>` 内；漏包会报 `Whole-document replacement requires a single top-level <doc> root`。详见 [popo-doc-content-format.md#doc-replace_page-必须用-doc-根节点包裹](./popo-doc-content-format.md#doc-replace_page-必须用-doc-根节点包裹)。

> ⚠️ **JS 转义陷阱（高频 bug）**：用 node 生成 HTML 时，连接各段**禁止用 `.join('\\n')`**——单引号字符串里 `\\n` 是字面「反斜杠+n」两字符，POPO 会把它当普通文本写进孤立 `<p>\n</p>`，全文到处冒 `\n`。正确写法 `.join('\n')`（单反斜杠 = 真实换行 LF）。`code-block` 内换行同理用真实 `\n`，不要写 `'\\n'`。`JSON.stringify` 会把真实换行序列化为 JSON 的 `\n`，反序列化后恢复 LF，这条链路是安全的——前提是源字符串里就是真实换行。

1. 可选：用 `popo_doc_search_folder_path` 查目标目录，提取 `folderId` 和 `teamSpaceId`；团队空间 URL 用 `popo_doc_get_folder_path` 解析 `teamSpaceId`。
2. ⚠️ 写入内容前**必须**读取 [popo-doc-content-format.md](./popo-doc-content-format.md)，content 使用自定义 HTML，**绝对禁止 Markdown**。
3. 用 `popo_doc_create_doc docType=1` 创建空文档（**不传 `content`**，或只传单行短内容），提取返回的 `docId`、`url`、`type`、`teamSpaceId`。
4. 用 `popo_doc_update_doc` 的 `doc.replace_page` 命令写入完整 HTML 内容；完整参数见 [doc-management-reference.md#doc_create_doc](./doc-management-reference.md#doc_create_doc) 和 [doc-update-reference.md](./doc-update-reference.md)。
5. 【重要】创建成功后如有 `save_artifact`，必须保存文档链接（`url`/`type`/`title` 必传）。

### Windows 可执行示例（两步法）

> ⚠️ **禁止用 PowerShell `ConvertTo-Json` 生成 command JSON**：中文弯引号 `"` `"`（U+201C/U+201D）会被规范化成普通双引号 `"` 且不转义，产生坏 JSON 导致 `command.type is required`。**必须用 node 的 `JSON.stringify`**，它对所有 Unicode 字符正确转义。

```powershell
# Step 1: 创建空 POPO 文档
popo-cli popo doc_create_doc docType=1 title="项目周报" parentId=<PARENT_ID> teamSpaceId=<TEAM_SPACE_ID>
# 返回 docId=<DOC_ID>

# Step 2: 用 node 生成 command JSON 临时文件（node 原生 JSON.stringify，正确转义所有字符）
$genScript = @'
const fs = require("fs");
const path = require("path");
// ⚠️ 用 join("\n") 真实换行，禁止 join("\\n")（字面反斜杠+n 会被当文本写入）
const parts = [
  "<h2>本周总结</h2>",
  "<p>完成事项...</p>",
  '<doc-li list-id="l1" list-type="unordered">需求评审</doc-li>',
  '<doc-li list-id="l1" list-type="unordered">接口联调</doc-li>',
];
// ⚠️ doc.replace_page 必须用 <doc> 根节点包裹
const html = "<doc>" + parts.join("\n") + "</doc>";
const cmd = { type: "doc.replace_page", content: html };
const tmp = path.join(require("os").tmpdir(), "popo_doc_cmd.json");
fs.writeFileSync(tmp, JSON.stringify(cmd), { encoding: "utf8" });
// 自校验：JSON 合法 + 无字面 \n 泄漏
try { JSON.parse(fs.readFileSync(tmp, "utf8")); } catch (e) { throw new Error("生成的 JSON 无效: " + e.message); }
if (html.includes("\\n")) throw new Error("HTML 含字面 \\n，检查 join 转义");
console.log(tmp);
'@
$cmdTmpFile = node -e $genScript

# Step 3: 用 =@file: 传 command 参数（路径必须用双引号包裹）
popo-cli popo doc_update_doc docId=<DOC_ID> teamSpaceId=<TEAM_SPACE_ID> command="@file:$cmdTmpFile"

# Step 4: 清理临时文件
Remove-Item -Path $cmdTmpFile -ErrorAction SilentlyContinue
```

### macOS / Linux 示例（可直接内联 command）

```bash
# Step 1: 创建空 POPO 文档
popo-cli popo doc_create_doc docType=1 title="项目周报"

# Step 2: 用 doc.replace_page 写入内容（单引号包裹 JSON，content 必须用 <doc> 包裹）
popo-cli popo doc_update_doc docId=<DOC_ID> command='{"type":"doc.replace_page","content":"<doc><h2>本周总结</h2><p>完成事项...</p></doc>"}'
```

> ❌ **错误写法**（content 误用 `=@file:`，内容会被当字面字符串写入）：
> ```
> popo-cli popo doc_create_doc docType=1 content="@file:/path/to/html.txt"   # 错！content 不支持 =@file:
> ```

---

## 工作流 1b: 创建 Markdown 文档并写入内容

适用：需要新建 docType=4 Markdown 文档并写入初始内容。**注意** 若用户没有限定 Markdown 文档，优先创建 POPO 文档（docType=1）。

> ⚠️ **`content` 参数是普通字符串，不支持 `=@file:` 语法**。多行/含特殊字符（`#`、`|`、`>`、反引号等）的 Markdown 内容在 Windows 上直接内联极易失败。**推荐两步法**：先建空文档（不传 `content`），再用 `doc_update_doc` 的 `md.replace_page` + `=@file:` 写入内容（`command` 参数才支持 `=@file:`）。

1. 可选：用 `popo_doc_search_folder_path` 查目标目录，提取 `folderId` 和 `teamSpaceId`；团队空间 URL 用 `popo_doc_get_folder_path` 解析 `teamSpaceId`。
2. 用 `popo_doc_create_doc docType=4` 创建空 Markdown 文档（**不传 `content`**，或只传单行短标题级内容），提取返回的 `docId`、`url`、`type`、`teamSpaceId`。
3. 用 `popo_doc_update_doc` 的 `md.replace_page` 命令写入完整 Markdown 内容；完整参数见 [doc-management-reference.md#doc_create_doc](./doc-management-reference.md#doc_create_doc) 和 [doc-update-reference.md](./doc-update-reference.md)。
4. 【重要】创建成功后如有 `save_artifact`，必须保存文档链接（`url`/`type`/`title` 必传）。

### Windows 可执行示例（两步法）

> ⚠️ **禁止用 PowerShell `ConvertTo-Json` 生成 command JSON**：中文弯引号 `"` `"`（U+201C/U+201D）会被规范化成普通双引号 `"` 且不转义，产生坏 JSON 导致 `command.type is required`。**必须用 node 的 `JSON.stringify`**，它对所有 Unicode 字符正确转义。

```powershell
# Step 1: 创建空 Markdown 文档
popo-cli popo doc_create_doc docType=4 title="AI在软件开发中的应用" parentId=<PARENT_ID> teamSpaceId=<TEAM_SPACE_ID>
# 返回 docId=<DOC_ID>

# Step 2: 用 node 生成 command JSON 临时文件（node 原生 JSON.stringify，正确转义所有字符）
$genScript = @'
const fs = require("fs");
const path = require("path");
const md = [
  "# AI在软件开发中的应用",
  "",
  "## 一、概述",
  "",
  "正文内容...",
  "",
  "| 工具 | 说明 |",
  "| --- | --- |",
  "| Copilot | 编程助手 |",
].join("\n");
const cmd = { type: "md.replace_page", content: md };
const tmp = path.join(require("os").tmpdir(), "popo_md_cmd.json");
fs.writeFileSync(tmp, JSON.stringify(cmd), { encoding: "utf8" });
// 自校验，确保 JSON 合法
try { JSON.parse(fs.readFileSync(tmp, "utf8")); } catch (e) { throw new Error("生成的 JSON 无效: " + e.message); }
console.log(tmp);
'@
$cmdTmpFile = node -e $genScript

# Step 3: 用 =@file: 传 command 参数（路径必须用双引号包裹）
popo-cli popo doc_update_doc docId=<DOC_ID> teamSpaceId=<TEAM_SPACE_ID> command="@file:$cmdTmpFile"

# Step 4: 清理临时文件
Remove-Item -Path $cmdTmpFile -ErrorAction SilentlyContinue
```

### macOS / Linux 示例（可直接内联 command）

```bash
# Step 1: 创建空 Markdown 文档
popo-cli popo doc_create_doc docType=4 title="项目周报"

# Step 2: 用 md.replace_page 写入内容（单引号包裹 JSON）
popo-cli popo doc_update_doc docId=<DOC_ID> command='{"type":"md.replace_page","content":"# 项目周报\n\n## 概述\n\n正文..."}'
```

> ❌ **错误写法**（content 误用 `=@file:`，内容会被当字面字符串写入）：
> ```
> popo-cli popo doc_create_doc docType=4 content="@file:/path/to/md.md"   # 错！content 不支持 =@file:
> ```

---

## 工作流 2: 下载文件资源（文档内嵌资源或 docType=3 文件类节点）

适用：用户要下载文档或表格内嵌的图片、附件、音视频等资源，或下载 docType=3 文件类文档节点。

### 文档内资源（`type=docResource`）

1. 用 `popo_doc_get_doc_detail` 读取文档内容。
2. 从 `content` 中提取内嵌文件 URL。
3. 用 `popo_doc_get_file_download_url type=docResource docId=<DOC_ID> urls=[...]` 把内嵌 URL 换成临时下载链接。
4. 从返回的 `downloadUrls` 取值；此场景 key 为原始资源 URL。
5. ⚠️ 不要直接把文档内的资源 URL 返回给用户；它可能没有独立鉴权。

### 文件类节点（`type=fileNode`）

1. 从 `popo_doc_search_doc`、`popo_doc_get_folder_children`、`popo_doc_get_doc_detail` 或 `popo_doc_create_file_node` 返回中确认目标是 docType=3，并提取节点 ID。
2. 调用 `popo_doc_get_file_download_url type=fileNode docIds=[...]` 获取临时下载链接；云空间 `docIds` 填 docId，团队空间 `docIds` 填 pageId。
3. 从返回的 `downloadUrls` 取值；此场景 key 为对应 `docId/pageId`，不是原始 URL。
4. ⚠️ 不要为文件类节点手动拼接下载地址，也不要把 `docUrl` 当作文件下载 URL。

### 多维表附件字段（docType=9）

1. 用 `popo_doc_datasheet_list` 取 `datasheetId`，云空间 `/pages/` 链接直接提取 `documentId` 和 `nodeId`。
2. 用 `popo_doc_field_list` 找到附件字段 `fieldId`。
3. 用 `popo_doc_record_page` / `popo_doc_record_filter` 取 `recordId` 和 `fileId`。
4. 用 `doc_file_batch_get` 获取附件文件信息和下载 URL（命令名就是 `doc_file_batch_get`）。

参考：[doc-resource-reference.md](./doc-resource-reference.md)、[file-node-reference.md](./file-node-reference.md)。

---

## 工作流 3: 上传文件并插入文档

适用：把本地或远程图片、附件、音视频插入 POPO 文档。

1. 按 [doc-resource-reference.md](./doc-resource-reference.md) 上传文档内资源；本地文件用 `popo_doc_upload_local_file`，远程 URL 用 `popo_doc_upload_file_from_url`。
2. 根据资源类型写入对应节点：图片 `<img>`，视频 `<video>`，音频 `<audio>`，其他文件 `<attachment>`。
3. 用 `popo_doc_update_doc` 插入节点，节点格式见 [popo-doc-content-format.md](./popo-doc-content-format.md)。
4. ⚠️ 不要把外链直接写进文档内容，先上传再插入。

最小示例：

```
popo-cli popo doc_upload_local_file file=@upload:/path/to/file.png docId=<DOC_ID>
popo-cli popo doc_update_doc docId=<DOC_ID> command='{"type":"doc.insert_after","content":"<img src=\"<FILE_URL>\" />"}'
```

> 🖥️ **Windows**:
> - 路径含中文/非 ASCII → 先复制到 ASCII 临时文件再上传。
> - `fileName` 含中文/特殊字符 → 必须用 `@text:` 临时文件传参。
> - `command` 参数 → 必须使用 `=@file:` 临时文件方式。
> - `src` URL：先对 `fileName` 值做 percent-encode，再把 `&` 替换为 `&amp;`。
> 详见 [doc-resource-reference.md](./doc-resource-reference.md)。

---

## 工作流 3b: 上传本地文件并创建文件类节点

适用：把本地 Word、PPT、Excel、PDF、图片、压缩包等文件创建为独立文件类文档节点（docType=3）。

1. 确认本地文件存在，读取 `fileName`（必须含后缀）和 `fileSize`（字节）。
2. 可选：确定目标目录：云空间用 `popo_doc_search_folder_path` / `popo_doc_get_folder_path`；团队空间先获取 `teamSpaceId`。
3. 调用 `popo_doc_get_s3_upload_url fileName=<FILE_NAME> fileSize=<SIZE>`，提取 `bucketName`、`objectKey`、`uploadId`、`uploadUrl`。
4. 把本地文件字节 PUT 到 `uploadUrl`。
5. PUT 成功（HTTP 2xx）后调用 `popo_doc_create_file_node` 创建节点。
6. 提取 `docId`、`docUrl`、`teamSpaceId?`，按需保存产物链接。

参考：[file-node-reference.md](./file-node-reference.md)。

> 🖥️ **Windows**: 涉及 JSON/HTML 的 `command` 参数必须用 `=@file:` 临时文件方式。

---

## 工作流 4: 创建表格并写入数据

适用：新建 docType=2 在线表格并写入初始单元格数据。

1. 用 `popo_doc_create_doc docType=2` 创建表格。
2. 用 `popo_doc_execute_table` 调 `workbook.getFullData` 获取 `sheetId`。
3. 用 `popo_doc_execute_table` 调 `sheet.batchSetCells` 批量写入；每次最多 1000 个单元格。
4. 可选：用 `sheet.batchGetCells` 验证写入结果。
5. 【重要】创建成功后如有 `save_artifact`，必须保存表格链接。

最小示例：

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type":"workbook.getFullData","payload":{}}'
```

表格 command 参数见 [sheet-tool-reference.md](./sheet-tool-reference.md)。

---

## 工作流 5: 创建图表

适用：在已有在线表格里基于单元格区域创建图表。

1. 先用 `workbook.getFullData` 或 `sheet.batchGetCells` 确认表格已有可用数据。
2. 用 `popo_doc_execute_table` 调 `sheet.addChart` 创建图表。
3. 可选：用 `sheet.chartList` 验证图表已创建。

图表参数见 [sheet-tool-reference.md](./sheet-tool-reference.md)。

---

## 工作流 6: 创建多维表并写入数据（含模板匹配）

适用：新建 docType=9 多维表，并创建用户需要的数据表、字段和初始记录。

1. 用 `popo_doc_create_doc docType=9` 创建多维表文档。
2. 【必须先执行】用 `popo_doc_datasheet_create` 创建用户需要的数据表和字段；字段类型见 [mtable-field-types.md](./mtable-field-types.md)。
3. 【创建成功后才执行】确认第 2 步成功后，再用 `popo_doc_datasheet_list` / `popo_doc_dashboard_list` 找出系统默认数据表和默认仪表盘。
4. 用 `popo_doc_datasheet_delete` 删除默认数据表和默认仪表盘（仅默认自带的）。
5. 用 `popo_doc_field_list` 获取字段列表，写记录时 `data` 的 key 必须用 `fieldId`。
6. 用 `popo_doc_record_batch_create` 写入初始记录。
7. 【重要】创建成功后如有 `save_artifact`，必须保存多维表链接。

⚠️ 关键顺序：先创建用户数据表，再清理默认数据表；顺序反了会导致多维表无数据表可保留而报错。

字段/筛选/模板参考：[mtable-field-types.md](./mtable-field-types.md)。

---

## 工作流 7: 在已有多维表中查询和更新记录

适用：按条件查找并更新已有多维表记录。

1. 如只有名称或描述，先用 `popo_doc_search_doc` 搜索并确认 `type=9`。
2. 用 `popo_doc_datasheet_list` 选择目标数据表，提取 `datasheetId`。
3. 用 `popo_doc_field_list` 获取字段列表，后续条件和更新数据都使用 `fieldId`。
4. 查询记录：`popo_doc_record_page` / `popo_doc_record_filter` / `popo_doc_record_batch_get`。
5. 更新记录：`popo_doc_record_filter_update` / `popo_doc_record_batch_update` / `popo_doc_cell_update`。

筛选条件见 [mtable-filter-guide.md](./mtable-filter-guide.md)，字段和值格式见 [mtable-field-types.md](./mtable-field-types.md)。

---

## 工作流 8: 创建多维表仪表盘

适用：给多维表创建仪表盘或追加 Widget。

1. 确认已有 `documentId` 和目标 `datasheetId`。
2. 用 `popo_doc_view_list` 获取 `viewId`。
3. 用 `popo_doc_field_list` 获取图表所需字段 ID。
4. 用 `popo_doc_dashboard_create` 创建仪表盘，或用 `popo_doc_widget_add` 追加 Widget。
5. ⚠️ Widget 的 `snapshot` **必须包含完整配置**，不要只传 `{"chartType": "pie"}`。

Widget 配置模板见 [mtable-widget-guide.md](./mtable-widget-guide.md)。

---

## 工作流 9: 设置表格整行或整列表格数据或者格式

适用：用户要求设置某一整行或某一整列的值、样式、格式、下拉、复选框、超链接或图片。

1. 用 `workbook.getFullData` 读取目标 Sheet，提取 `rowCount` 和 `colCount`。
2. 设置整行时，用 `colCount` 构造目标行从 `0` 到 `colCount - 1` 的全部 cells。
3. 设置整列时，用 `rowCount` 构造目标列从 `0` 到 `rowCount - 1` 的全部 cells。
4. 用 `sheet.batchSetCells` 一次性写入；不要只写已有值单元格。
5. 可选：用 `sheet.batchGetCells` 读取目标行或目标列验证。

⚠️ `workbook.getFullData` 返回的 `cells` 是有值单元格的稀疏数组，不能用 `cells.length` 判断行列总数。
⚠️ `sheet.batchSetCells` 每次最多写入 1000 个单元格；目标行/列超过 1000 个单元格时必须拆成多次调用。

最小示例：

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type":"workbook.getFullData","payload":{"sheetId":"<SHEET_ID>"}}'
```
