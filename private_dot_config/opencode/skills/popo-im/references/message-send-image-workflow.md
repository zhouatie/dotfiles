# 发送图片消息 — 执行流程

> 本流程适用于 P2P 单聊和群聊。图片不是特殊消息类型，以**纯文本**发送 `[img]FP地址[/img]` 标签。

> 🖥️ **Windows 平台必读（不可跳过）**：
> 所有 `curl` 命令**必须替换为 `curl.exe`**（PowerShell 中 `curl` 是 `Invoke-WebRequest` 别名，参数不兼容，会导致 `ParameterBindingException`）。每个涉及 curl 的 Step 都有独立的 Windows 命令段，请严格使用。

## 前置条件

- 已确定接收方：
  - 用户直接提供 `xxx@corp.netease.com` 或 `xxx@mesg.corp.netease.com` 格式的 POPO 账号 → 直接作为 uid 使用
  - 用户提供人名 → P2P 用 `popo_userinfo_search` 获取 uid；群聊用 `popo_team_search` 获取 tid
- 用户已提供要发送的图片文件**本地路径**（支持批量）

## Step 1: 获取 FP 上传地址

调用 `popo_message_fp_upload_url`（**无参数**）获取上传信息：

```bash
popo-cli popo message_fp_upload_url
```

### 返回值

返回 JSON 路径为 `data.data.data.data`（四层嵌套），包含：

```json
{
  "uploadUrl": "http://devfp.ps.netease.com/popo/file/new/",
  "token": "Policy xxx:base64..."
}
```

| 字段 | 说明 |
|------|------|
| `uploadUrl` | FP 上传端点（所有图片共用同一端点地址） |
| `token` | Policy 认证令牌，通过 `Authorization` header 传递 |

> 批量发送时，每个文件需**单独调用一次**获取上传地址（token 有时效性）。

## Step 2: 获取文件大小

上传时**必须**传 `Content-Length` header，需先获取文件字节数：

### macOS

```bash
file_size=$(stat -f%z "{file_path}")
```

### Linux

```bash
file_size=$(stat -c%s "{file_path}")
```

### Windows (PowerShell)

```powershell
$file_size = (Get-Item "{file_path}").Length
```

## Step 3: 上传图片文件

使用 **`curl POST --data-binary`** 将图片以 raw binary 方式上传。

⚠️ **FP 上传方式与 S3 不同**：
- FP 用 `POST` + `--data-binary`（raw binary body）+ `Authorization` header
- S3 用 `PUT` + `-T`（upload-file）+ 预签名 URL（无需 header）

### macOS / Linux

```bash
curl -s -X POST "{uploadUrl}" -H "Authorization: {token}" -H "Content-Length: {file_size}" --data-binary "@{file_path}"
```

### Windows (PowerShell)

> ⚠️ **必须使用 `curl.exe`**：PowerShell 中 `curl` 是 `Invoke-WebRequest` 的别名，参数格式不兼容，会导致 `ParameterBindingException`。使用 `curl.exe` 可直接调用系统自带的 curl 二进制文件。

```powershell
curl.exe -s -X POST "{uploadUrl}" -H "Authorization: {token}" -H "Content-Length: {file_size}" --data-binary "@{file_path}"
```

> - `{uploadUrl}` 替换为 Step 1 返回的 `uploadUrl` 字段值
> - `{token}` 替换为 Step 1 返回的 `token` 字段值（含 `Policy` 前缀）
> - `{file_size}` 替换为 Step 2 获取的文件字节数
> - `{file_path}` 替换为用户提供的本地图片路径

### 成功响应

HTTP 200，返回 JSON：

```json
{
  "url": "https://devfp.ps.netease.com/popo/file/69ea25813bba2c9ed5b5ecf6zYfRWzsl02",
  "mime": "image/jpeg; charset=binary",
  "fsize": 253247,
  "md5": "3eec9a8422180e99ad7c95497bb5329e",
  "picSize": [1054, 631]
}
```

| 字段 | 说明 |
|------|------|
| `url` | **图片的 FP 永久地址**（用于组装 `[img]` 标签） |
| `mime` | 文件 MIME 类型 |
| `fsize` | 文件大小（字节） |
| `md5` | 文件 MD5 哈希 |
| `picSize` | 图片尺寸 `[宽, 高]` |

提取 **`url`** 字段用于 Step 4。

### 失败响应

HTTP 非 200，返回错误文本（如 `Require Token` 等）。

## Step 4: 组装消息

将所有上传成功的图片 `url` 用 `[img]...[/img]` 标签包裹，拼接成 `message` 参数：

- 单张图片：`[img]https://devfp.ps.netease.com/popo/file/xxx[/img]`
- 多张图片拼接：`[img]{url1}[/img][img]{url2}[/img][img]{url3}[/img]`

## Step 5: 发送消息

以**纯文本**方式发送（图片走文本类型，msgType 不传或传 1）：

### macOS / Linux

#### P2P 发送

```bash
popo-cli popo message_send_p2p message="[img]{url}[/img]" receiver=zhangsan@example.com source=AGENT
```

#### 群聊发送

```bash
popo-cli popo message_send_team message="[img]{url}[/img]" receiver=group_123 source=AGENT
```

### Windows (PowerShell)

> ⚠️ **铁律**：FP 返回的图片 url **通常含 `&`、`?`、`=`、长 hash**，在 shell 中直接拼接 `message="[img]$url[/img]"` 必炸（`&` 会被解析为命令分隔符 / 后台运行符）。Windows 平台**强制**通过 `@text:` 临时文件传递。

```powershell
# === 单张图片 ===
$msgContent = "[img]$url[/img]"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))

    # P2P 发送
    popo-cli popo message_send_p2p message="@text:$msgTmpFile" receiver=zhangsan@example.com source=AGENT

    # 群聊发送
    popo-cli popo message_send_team message="@text:$msgTmpFile" receiver=group_123 source=AGENT

    # 文件传输助手
    popo-cli popo message_send_filehelper message="@text:$msgTmpFile" source=AGENT
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}

# === 多张图片拼接 ===
$msgContent = "[img]$url1[/img][img]$url2[/img][img]$url3[/img]"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo message_send_team message="@text:$msgTmpFile" receiver=group_123 source=AGENT
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}
```

> **自检要点**：
> - 写文件前 `Write-Host $msgContent`，确认形如 `[img]http://devfp.../...[/img]`，url **未被截断**
> - popo-cli 调用行的 `message` 必须是 `message="@text:$msgTmpFile"`（带双引号），**不是** `message=@text:$msgTmpFile`
> - **`try/finally` 是强制的**：保证任何异常路径（popo-cli 报错 / 用户 Ctrl+C / 上层 `$ErrorActionPreference='Stop'`）下临时文件都会被清理

## 典型场景

```
用户："帮我给张三发一张图片 /Users/xxx/test.jpg"
  ├─ Step 0: popo_userinfo_search("张三") → zhangsan@example.com
  ├─ Step 1: popo-cli popo message_fp_upload_url
  │          → uploadUrl="http://devfp.ps.netease.com/popo/file/new/", token="Policy xxx:base64..."
  ├─ Step 2: stat -f%z → file_size=253247
  ├─ Step 3: curl -s -X POST "{uploadUrl}" -H "Authorization: {token}" -H "Content-Length: 253247" --data-binary "@/Users/xxx/test.jpg"
  │          → { "url": "https://devfp.ps.netease.com/popo/file/69ea25813bba..." }
  ├─ Step 4: message = "[img]https://devfp.ps.netease.com/popo/file/69ea25813bba...[/img]"
  └─ Step 5: popo-cli popo message_send_p2p message="[img]https://devfp.ps.netease.com/popo/file/69ea25813bba...[/img]" receiver="zhangsan@example.com" source=AGENT
```

```
用户："帮我把这张图片发送给 yuexichun@corp.netease.com /Users/xxx/test.jpg"
  ├─ Step 1: popo-cli popo message_fp_upload_url（用户直接提供了 POPO 账号，跳过 popo_userinfo_search）
  │          → uploadUrl="http://devfp.ps.netease.com/popo/file/new/", token="Policy xxx:base64..."
  ├─ Step 2: stat -f%z → file_size=253247
  ├─ Step 3: curl -s -X POST "{uploadUrl}" -H "Authorization: {token}" -H "Content-Length: 253247" --data-binary "@/Users/xxx/test.jpg"
  │          → { "url": "https://devfp.ps.netease.com/popo/file/69ea25813bba..." }
  ├─ Step 4: message = "[img]https://devfp.ps.netease.com/popo/file/69ea25813bba...[/img]"
  └─ Step 5: popo-cli popo message_send_p2p message="[img]https://devfp.ps.netease.com/popo/file/69ea25813bba...[/img]" receiver="yuexichun@corp.netease.com" source=AGENT
```

```
用户："在项目群里发三张截图 ~/a.png ~/b.png ~/c.png"
  ├─ Step 0: popo_team_search("项目群") → tid=group_456
  ├─ Step 1: 分别调用 3 次 popo-cli popo message_fp_upload_url → 3 组 uploadUrl + token
  ├─ Step 2: 分别获取 3 个文件大小
  ├─ Step 3: 分别 curl POST 上传 3 张图片 → 3 个 FP url
  ├─ Step 4: message = "[img]{url1}[/img][img]{url2}[/img][img]{url3}[/img]"
  └─ Step 5: popo-cli popo message_send_team message="[img]{url1}[/img][img]{url2}[/img][img]{url3}[/img]" receiver="group_456" source=AGENT
```

## 错误处理

| 阶段 | 失败条件 | 处理方式 |
|------|---------|---------|
| Step 1 | `popo-cli` 返回错误 | 报告错误信息给用户，终止流程 |
| Step 2 | 文件不存在或无读取权限 | 报告文件路径无效，终止流程 |
| Step 3 | curl 返回非 200 | 报告上传失败，附带错误信息（如 `Require Token` 表示认证失败） |
| Step 5 | 消息发送失败 | 报告发送失败，附带错误信息 |
| 批量 | 部分文件上传失败 | 发送已成功上传的图片，报告失败的文件列表 |

## FP 与 S3 上传方式对比

| | FP 图片上传 | S3 文件上传 |
|---|---|---|
| **获取地址** | `popo-cli popo message_fp_upload_url`（无参数） | `popo-cli popo message_s3_ufile_upload fsize=X fhash=Y` |
| **HTTP 方法** | POST | PUT |
| **curl 命令** | `--data-binary "@file"` | `-T "file"` |
| **认证方式** | `Authorization` header（Policy token） | URL query params（预签名） |
| **需要 Content-Length** | 是 | 否 |
| **响应 body** | JSON（含 `url` 等字段） | 无 body |
| **永久地址来源** | 响应 JSON 的 `url` 字段 | 请求时的 URL 本身 |
