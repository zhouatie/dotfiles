# 文档内资源工具参考

用于上传或下载文档内容中的图片、附件、视频、音频等资源。不要把这些工具用于创建独立文件类节点（docType=3）。

## 调用前检查

- 插入文档内图片、附件、视频、音频前，必须先调用 `popo_doc_upload_local_file`（本地文件）或 `popo_doc_upload_file_from_url`（远程 URL）获取 URL，再写入 `img`、`video`、`audio`、`attachment` 等内容标签，详见 [popo-doc-content-format.md](./popo-doc-content-format.md)。
- `popo_doc_upload_local_file` 必须用 `popo-cli` 直接调用，且本地路径必须使用 `@upload:` 前缀；不要用 JSON call 方式。
- 下载文档内资源必须通过 `popo_doc_get_file_download_url(type=docResource)` 获取临时下载链接，不要直接下载原始资源地址。
- 文件类节点（docType=3）的上传/下载见 [file-node-reference.md](./file-node-reference.md)。

---

## popo_doc_upload_local_file

上传本地文件并获取可写入文档内容的 URL。用于先上传图片、视频、音频、附件等资源，再通过 `popo_doc_update_doc` 插入到文档中。

> 文件尺寸上限 100MB。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `file` | String | 是 | 要上传的本地文件地址，要加上 `@upload:` 前缀。可附 `;type=mime` 显式指定 Content-Type，例如 `file=@upload:./report.pdf;type=application/pdf`。`@upload:` 路径含空格或特殊字符时必须整体用双引号包裹。 |
| `docId` | String | 是 | 文档ID；资源要插入的目标文档 |
| `teamSpaceId` | String | 否 | 团队空间ID；目标文档在团队空间时必传 |
| `fileName` | String | 否 | **显示用文件名**，会写入返回 URL 的 `&fileName=...` 查询参数，决定用户点击下载时保存的文件名。**不传时**默认使用 `file` 路径的 basename。**强烈建议**：当 `file` 因编码/特殊字符问题被复制到临时文件后，必须用 `fileName` 显式传入原始文件名，否则下载将得到 `popo_doc_upload_xxxx.ext` 这类临时名。支持 `@text:<tempfile>` 文件传参（避免命令行中文乱码）。 |

### 返回值

String，文件 URL 链接，形如：
`https://cospread.cowork.netease.com/api/admin/file/download?path=<HASH>&type=attachment&identity=<DOC_ID>&fileName=<显示用文件名>`

> ⚠️ 返回 URL 末尾的 `&fileName=...` 决定**下载时的保存名**。如果上传用的是临时副本，**必须**通过 `fileName` 参数显式指定原始文件名，否则用户下载得到的就是 `popo_doc_upload_xxxx.ext`。

### ⚠️ 非 ASCII 文件名处理（核心模式：file 走临时副本 + fileName 走 @text: 原名）

当文件路径包含中文或其他非 ASCII 字符时，`popo-cli` 内部序列化会因 `ByteString` 编码限制而报错：

```
Cannot convert argument to a ByteString because the character at index N has a value of XXXXX which is greater than 255.
```

**核心解决思路**（与 popo-im `message_s3_ufile_upload_complete` 的 `fname` 处理完全一致）：
- **`file` 参数** → 复制到 ASCII 安全临时路径，仅传文件**内容**通道
- **`fileName` 参数** → 单独传**原始文件名**（含中文/特殊字符），通过 `@text:<UTF-8 无 BOM 临时文件>` 传参，绕过命令行编码

> **注意**：判断标准为文件路径中是否包含任何非 ASCII 字符（Unicode 码点 > 127），中文、日文、韩文、emoji 等均会触发。若文件名本身是 ASCII 但上级目录含中文，同样需要临时复制；此时 `fileName` 仍可省略（basename 已是纯 ASCII 且与原名一致）。

#### macOS / Linux

```bash
# 判断文件路径是否包含非 ASCII 字符（当前路径或文件名含中文均会触发）
# → 若是：复制到 /tmp 用 ASCII 安全文件名 + 用 fileName 传原名
# → 若否：直接上传（可省略 fileName）

# 含中文路径 → 先复制到临时目录
cp "/path/含中文路径/中文文件名.log" "/tmp/popo_upload_tmp_file.log"

# 上传时显式传入原始文件名（关键！否则返回 URL 的 fileName= 会变成 popo_upload_tmp_file.log）
popo-cli popo doc_upload_local_file \
  file="@upload:/tmp/popo_upload_tmp_file.log" \
  fileName="中文文件名.log" \
  docId=<DOC_ID>
```

#### Windows (PowerShell)

> 🖥️ **Windows 平台双重编码 + 特殊字符问题**：
> 1. `popo-cli` 本身有 ByteString 限制（同 macOS/Linux）
> 2. PowerShell 控制台编码为 **GBK**，中文路径/文件名通过命令行传递时额外叠加一层乱码
> 3. 路径中含 `&`（命令分隔符）、空格（参数拆分）、`()`（子表达式）、`[]`（glob 通配）时，PowerShell 会错误解析
>
> **解决方案**：
> - 原文件路径用**单引号字面量**存储（防止 `$`、`&`、`()` 被解析）
> - `Copy-Item` 用 `-LiteralPath`（防止 `[]` 被 glob 展开）
> - 复制到 ASCII + 特殊字符安全的临时路径后上传（`file` 参数）
> - **原始文件名写入 UTF-8 无 BOM 临时文件**，通过 `fileName="@text:$fnameTmpFile"` 传参（与 popo-im 的 `fname` 处理完全一致）
> - `@upload:` / `@text:` 路径值用**双引号包裹**（`"@upload:$safeFile"`、`"@text:$fnameTmpFile"`），防止空格/`&` 拆参数
> - `command` JSON 使用 `=@file:` 临时文件传参，**必须用 node 的 `JSON.stringify` 生成**（禁止 PowerShell `ConvertTo-Json`，会把中文弯引号规范化成普通双引号导致坏 JSON）

```powershell
# Step 0: 用单引号字面量存储原路径（&、$、() 均安全）
$uploadFile = '<ORIGINAL_FILE_PATH>'  # 例: 'C:\Users\test\我的 & 报告 (final).pdf'

# Step 1: 提取原始文件名（含中文/特殊字符均安全，PS 内部 UTF-16）
$originalName = [System.IO.Path]::GetFileName($uploadFile)  # 例: '我的 & 报告 (final).pdf'

# Step 2: 构造 ASCII + 特殊字符安全的临时上传副本（GUID 保证唯一且安全）
$ext = [System.IO.Path]::GetExtension($uploadFile)
$safeFile = Join-Path $env:TEMP "popo_doc_upload_$([System.Guid]::NewGuid().ToString('N').Substring(0,8))$ext"

# Step 3: 复制（-LiteralPath 防止 [] glob 展开）
Copy-Item -LiteralPath $uploadFile -Destination $safeFile -Force

# Step 4: 将原始文件名写入 UTF-8 无 BOM 临时文件（禁止 Set-Content / Out-File）
$fnameTmpFile = Join-Path $env:TEMP "popo_doc_fname_$([System.Guid]::NewGuid().ToString('N').Substring(0,8)).txt"
[System.IO.File]::WriteAllText($fnameTmpFile, $originalName, [System.Text.UTF8Encoding]::new($false))

# Step 5: 上传（@upload: 走临时副本；fileName 走 @text: 临时文件传原名；两处路径都必须双引号包裹）
popo-cli popo doc_upload_local_file `
  file="@upload:$safeFile" `
  fileName="@text:$fnameTmpFile" `
  docId=<DOC_ID>

# Step 6: 清理（全部使用 -LiteralPath）
Remove-Item -LiteralPath $safeFile, $fnameTmpFile -ErrorAction SilentlyContinue
```

> **禁止**在 Windows 命令行中直接传递含中文或特殊字符的路径给 `@upload:` 参数，也**禁止**直接把含中文的原始文件名作为 `fileName=中文名.xlsx` 字面拼到命令行（必经 GBK，必乱码）。即使文件名本身是 ASCII，若上级目录含中文或特殊字符，同样需要复制。`Copy-Item` / `Remove-Item` 始终使用 `-LiteralPath`。

### 示例

```
# 纯 ASCII 路径，无需 fileName 参数
popo-cli popo doc_upload_local_file file="@upload:/Users/Download/xxxx.png" docId=<DOC_ID>

# 中文文件名（macOS/Linux），先复制再用 fileName 传原名
cp "/Users/zhangsan/季度报告.xlsx" "/tmp/popo_doc_upload_tmp.xlsx"
popo-cli popo doc_upload_local_file file="@upload:/tmp/popo_doc_upload_tmp.xlsx" fileName="季度报告.xlsx" docId=<DOC_ID>
# 返回: https://...&fileName=季度报告.xlsx  ✅
```

上传成功后，将返回的 URL 写入文档内容：

```bash
popo-cli popo doc_update_doc docId=<DOC_ID> command='{"type": "doc.insert_after", "content": "<img src=\"<FILE_URL>\" />"}'

# ⚠️ <attachment> 必须包含三个属性：file-name、file-size（B，服务端强校验）、src
# ⚠️ src 中的 & 必须转义为 &amp;，且 fileName 查询参数的中文/空格/& 必须百分号编码（详见 workflows.md 工作流 3）
popo-cli popo doc_update_doc docId=<DOC_ID> command='{"type": "doc.insert_after", "content": "<attachment file-name=\"report.pdf\" file-size=\"102400\" src=\"<FILE_URL_AMP_ESCAPED_AND_FILENAME_ENCODED>\" />"}'
```

### 禁止写法

```
# 缺少 @upload: 前缀
popo-cli popo doc_upload_local_file file=/tmp/report.pdf docId=<DOC_ID>

# 试图走 JSON/file 字段上传（不支持）
popo-cli popo doc_upload_local_file docId=<DOC_ID> file=@file:/tmp/report.pdf
```

---

## popo_doc_upload_file_from_url

从远程 URL 下载文件并上传到目标文档，获取可写入文档内容的 URL。适用于 Web/CDN 场景。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `url` | String | 是 | 远程文件 URL |
| `docId` | String | 是 | 文档ID；资源要插入的目标文档 |
| `teamSpaceId` | String | 否 | 团队空间ID；目标文档在团队空间时必传 |

### 返回值

String，文件 URL 链接。

### 示例

```
popo-cli popo doc_upload_file_from_url url=https://cdn.example.com/assets/report.pdf docId=<DOC_ID>
```

---

## popo_doc_get_file_download_url(type=docResource)

获取文档内图片、附件、音视频等资源的临时下载地址（预签名 URL）。

> 不适用于多维表(docType=9)附件字段；多维表附件下载必须使用 [mtable-tool-reference.md](./mtable-tool-reference.md) 中的 `doc_file_batch_get`（实际命令名无 `popo_` 前缀，不是 `popo_doc_file_batch_get`）。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `type` | String | 是 | 固定传 `docResource` |
| `docId` | String | 是 | 文档 ID；云空间为 docId，团队空间为 pageId |
| `teamSpaceId` | String | 否 | 团队空间 ID；传值表示团队空间文档，不传表示云空间文档 |
| `urls` | List<String> | 是 | 未签名的文档内资源地址列表 |

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `downloadUrls` | Map<String, String> | value 为预签名下载地址；key 为原始资源 URL |

### 示例

```
popo-cli popo doc_get_file_download_url type=docResource docId=abc123 urls='["https://nos.netease.com/xxx/file1.png","https://nos.netease.com/xxx/file2.pdf"]'

# 团队空间文档必须追加 teamSpaceId
popo-cli popo doc_get_file_download_url type=docResource docId=page_xxx teamSpaceId=ts_xxx urls='["https://nos.netease.com/xxx/file1.png"]'
```
