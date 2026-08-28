# POPO Task — 附件上传工作流

> 适用 tool：`task_attachment_add`（写操作 ⛔，第一步先回显摘要 + 等用户确认，确认后才执行上传）。
> 字段权威定义见 [`tool-reference.md`](./tool-reference.md#11-task_attachment_add--附件登记写操作-)。

---

## 0. type → 上传通道总览

| type | 通道 | 上传链路 | 用户提供 |
|---|---|---|---|
| `1` 图片 | FP（POST + Authorization header） | `message_fp_upload_url` → `curl POST --data-binary` → `task_attachment_add` | 本地图片路径 |
| `2` 文件 | S3（PUT + 预签名 URL） | `message_s3_ufile_upload` → `curl -T` → `message_s3_ufile_upload_complete` → `task_attachment_add` | 本地文件路径 |
| `3` 云空间链接 | 无（直接登记） | （跳过上传） → `task_attachment_add` | 云空间 docId + docUrl |

> 上传 3 步（`message_fp_upload_url` / `message_s3_ufile_upload` / `message_s3_ufile_upload_complete`）是 **fabric 全局工具**，本就跨 skill 共享；本文档独立记录上传步骤是为了 skill 自给自足，**不**依赖 popo-im 安装。

---

## 1. type=1 图片附件完整步骤

```
Step 1  获取文件大小（byte 大小）

Step 2  回显附件摘要 + 调用 ask_user_question 提供选项
        "将给任务【<title>】添加附件【<name>】（图片，<size> 字节）"
        ├─ 选项：["确认添加", "取消"]
        └─ 用户选「取消」→ 终止，不执行任何上传

Step 3  popo-cli popo message_fp_upload_url      # 无参数
        → 返回 uploadUrl + token

Step 4  curl POST --data-binary 上传
        → 返回 JSON 含 url（图片 FP 永久地址）

Step 5  task_attachment_add taskId=<...> attachments="[{type:1, url:<FP url>, name, size}]"
```

### 1.1 命令示例

#### macOS / Linux

```bash
# Step 1
popo-cli popo message_fp_upload_url
# 提取 uploadUrl 与 token

# Step 2
file_size=$(stat -f%z "/Users/xxx/a.png")   # macOS（Linux 用 stat -c%s）

# Step 3
curl -s -X POST "{uploadUrl}" \
  -H "Authorization: {token}" \
  -H "Content-Length: $file_size" \
  --data-binary "@/Users/xxx/a.png"
# 响应 JSON 中的 url 字段即图片 FP 永久地址

# Step 5（用户确认后）
popo-cli popo task_attachment_add taskId=t_12345 \
  attachments="[{\"type\":1,\"url\":\"https://devfp.ps.netease.com/popo/file/...\",\"name\":\"a.png\",\"size\":253247}]"
```

#### Windows (PowerShell)

> ⚠️ PowerShell 中 `curl` 是 `Invoke-WebRequest` 别名，必须用 **`curl.exe`**。

```powershell
# Step 1
popo-cli popo message_fp_upload_url

# Step 2
$file_size = (Get-Item "C:\xxx\a.png").Length

# Step 3
curl.exe -s -X POST "{uploadUrl}" `
  -H "Authorization: {token}" `
  -H "Content-Length: $file_size" `
  --data-binary "@C:\xxx\a.png"

# Step 5（用户确认后）
popo-cli popo task_attachment_add taskId=t_12345 `
  attachments="[{\""type\"":1,\""url\"":\""<FP url>\"",\""name\"":\""a.png\"",\""size\"":$file_size}]"
```

---

## 2. type=2 文件附件完整步骤

```
Step 1  计算 fsize / fhash(MD5) / fname / fext

Step 2  回显附件摘要 + 调用 ask_user_question 提供选项
        "将给任务【<title>】添加附件【<fname>】（文件，<fsize> 字节）"
        ├─ 选项：["确认添加", "取消"]
        └─ 用户选「取消」→ 终止，不执行任何上传

Step 3  popo-cli popo message_s3_ufile_upload fsize=X fhash=Y
        → 返回 url（S3 预签名）、objectKey、bucketName

Step 4  curl -T（PUT upload-file）上传到预签名 url
        ⚠️ 必须 -T，不能 --data-binary，否则签名校验失败

Step 5  popo-cli popo message_s3_ufile_upload_complete
            fsize=X fhash=Y objectKey=Z fname=N bucketName=B clientType=3
        → 返回 ufid（fileId）、ftype（infoType 一般固定为 3）

Step 6  task_attachment_add 传：
        {type:2, url:"", name:fname, size:fsize, format:fext,
         md5:fhash, fileId:ufid, infoType:3, objectKey}
        ⚠️ type=2 时 url **必须为空字符串 ""**（不是不传，是显式空串）
```

### 2.1 计算元数据 — macOS / Linux

```bash
file_path="/Users/xxx/report.pdf"
fsize=$(stat -f%z "$file_path")            # macOS（Linux: stat -c%s）
fhash=$(md5 -q "$file_path")               # macOS（Linux: md5sum ... | awk '{print $1}'）
fname=$(basename "$file_path")
fext="${fname##*.}"
echo "$fsize $fhash $fname $fext"
```

### 2.2 计算元数据 — Windows (PowerShell)

> ⚠️ Windows 中文文件名 stdout 必乱码（GBK），`fname` 写入 UTF-8 无 BOM 临时文件，后续步骤通过 `=@text:` 读回。

```powershell
$file_path = "C:\xxx\报表.pdf"
$f = Get-Item $file_path
$fsize = $f.Length
$fhash = (Get-FileHash $file_path -Algorithm MD5).Hash.ToLower()
$fext  = $f.Extension.TrimStart('.')
$fnameTmp = Join-Path $env:TEMP "popo_task_fname.txt"
[System.IO.File]::WriteAllText($fnameTmp, $f.Name, [System.Text.UTF8Encoding]::new($false))
Write-Output "$fsize $fhash $fext"
```

### 2.3 上传 — macOS / Linux

```bash
# Step 3（ask_user_question 确认后执行）
popo-cli popo message_s3_ufile_upload fsize=$fsize fhash=$fhash
# 提取 url / objectKey / bucketName

# Step 4
curl -s -w "%{http_code}" -T "$file_path" "{url}"
# 期望 HTTP 200，无 body

# Step 5
popo-cli popo message_s3_ufile_upload_complete \
  fsize=$fsize fhash=$fhash objectKey=$objectKey \
  fname="$fname" bucketName=$bucketName clientType=3
# 提取 ufid / ftype

# Step 6
popo-cli popo task_attachment_add taskId=t_12345 \
  attachments="[{\"type\":2,\"url\":\"\",\"name\":\"$fname\",\"size\":$fsize,\"format\":\"$fext\",\"md5\":\"$fhash\",\"fileId\":\"$ufid\",\"infoType\":3,\"objectKey\":\"$objectKey\"}]"
```

### 2.4 上传 — Windows (PowerShell)

```powershell
# Step 3（ask_user_question 确认后执行）
popo-cli popo message_s3_ufile_upload fsize=$fsize fhash=$fhash

# Step 4 — 必须 curl.exe，不能 PS 别名
curl.exe -s -w "%{http_code}" -T $file_path "{url}"

# Step 5 — fname 通过 @text:文件路径 读回 UTF-8 无 BOM 文件
$fnameTmp = Join-Path $env:TEMP "popo_task_fname.txt"
popo-cli popo message_s3_ufile_upload_complete `
  fsize=$fsize fhash=$fhash objectKey=$objectKey `
  fname="@text:$fnameTmp" bucketName=$bucketName clientType=3

# Step 6 — attachments JSON 写入临时文件后用 @text:
$attachObj = @(@{
  type      = 2
  url       = ''
  name      = [string][System.IO.File]::ReadAllText($fnameTmp, [System.Text.UTF8Encoding]::new($false))
  size      = [int64]$fsize
  format    = [string]$fext
  md5       = [string]$fhash
  fileId    = [string]$ufid
  infoType  = 3
  objectKey = [string]$objectKey
})
$attachJson = $attachObj | ConvertTo-Json -Compress
$attachTmp = Join-Path $env:TEMP "popo_task_attach.json"
[System.IO.File]::WriteAllText($attachTmp, $attachJson, [System.Text.UTF8Encoding]::new($false))

popo-cli popo task_attachment_add taskId=t_12345 attachments="@text:$attachTmp"
```

---

## 3. type=3 云空间链接完整步骤

```
Step 1  用户提供 云空间已有 文档 URL + docId
        例：docId="doc_abc"  docUrl="https://docs.popo.netease.com/<...>"
        ⚠️ 本流程**不**经过任何上传通道，云空间链接是已存在资源

Step 2  回显附件摘要 + 调用 ask_user_question 提供选项
        "将给任务【<title>】添加云空间文档【<docUrl>】"
        ├─ 选项：["确认添加", "取消"]
        └─ 用户选「取消」→ 终止

Step 3  task_attachment_add
```

```bash
popo-cli popo task_attachment_add taskId=t_12345 \
  attachments="[{\"type\":3,\"url\":\"\",\"docId\":\"doc_abc\",\"docUrl\":\"https://docs.popo.netease.com/...\",\"docOwnerUid\":\"alice@corp.com\"}]"
```

> 一期**不**支持 popo-cli 端新建云空间文档（不走 popo-doc 上传链路）— 用户必须自行提供 URL。

---

## 4. 错误兜底

| 失败点 | 处理 |
|---|---|
| 用户在确认环节回"取消 / 算了" | 立即终止，不执行任何上传操作 |
| `message_fp_upload_url` / `message_s3_ufile_upload` 返回错误 | 报告错误码与文案，终止当前附件，不进入 `task_attachment_add` |
| `curl` 返回非 200 | 报告 HTTP 码与（如有）错误 body（XML），建议用户重试或检查网络 |
| `message_s3_ufile_upload_complete` 返回错误 | S3 已上传但 ufid 未拿到，提示用户重试 Step 5；不调 `task_attachment_add` |
| `task_attachment_add` 返回错误 | 报告错误，告知用户附件文件已上传但未登记到任务，建议重试 Step 6 |
| `task_attachment_add` 返回 `status=100403`（无权限） | 解析 message 中的 taskId/required/action，明确提示"无权限给任务 <taskId> 登记附件，所需权限 CAN_EDIT，请联系任务创建者/管理员"。**不重试**登记步骤（文件已上传，权限恢复后可凭 ufid 重新登记，无需重复上传） |
| 批量多附件，部分失败 | 报告成功 N、失败 M 的清单（含 name 与原因），不重试失败项 |

---

## 5. 客户端 `todo_attachment_uploader.cpp` 等价路径对照

> 用于核对本文档与客户端实现一致性（仅作开发者参考，不在 AI 输出中展示）。

| 客户端步骤 | 本文档对应 |
|---|---|
| `TodoAttachmentUploader::uploadImage()` — 调 FP 接口拿 token+url，POST 上传，登记 `type=1` 附件 | type=1 §1 全套 |
| `TodoAttachmentUploader::uploadFile()` — 调 S3 接口 3 步，登记 `type=2` 附件（url 空、含 fileId/objectKey/md5/format/infoType=3） | type=2 §2 全套 |
| `TodoAttachmentUploader::addCloudDocReference()` — 用户从云空间选择已有文档，仅登记 docId+docUrl 为 `type=3` | type=3 §3 |
| `TodoAttachmentUploader::onUploadCanceled()` — 用户取消上传，不调 attachment 接口 | §4 兜底 |
