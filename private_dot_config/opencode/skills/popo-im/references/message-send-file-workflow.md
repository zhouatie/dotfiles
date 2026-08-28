# 发送文件消息 — 执行流程

> 本流程适用于 P2P 单聊和群聊。文件消息使用 **msgType=3**（S3 文件类型）。

> 🖥️ **Windows 平台必读（不可跳过）**：
> 1. 所有 `curl` 命令**必须替换为 `curl.exe`**（PowerShell 中 `curl` 是 `Invoke-WebRequest` 别名，参数不兼容）
> 2. 中文文件名（`fname`）**禁止通过 `Write-Output` / stdout 输出**（GBK 乱码无法避免），必须写入 UTF-8 无 BOM 临时文件
> 3. **JSON 一律走"对象 → ConvertTo-Json → WriteAllText 文件 → @text:"** 四步，**严禁手工拼 JSON 字符串**
> 4. **shell 仅负责传文件路径，不负责构造/转义 JSON**；所有 `@text:` 路径必须用双引号包裹（`"@text:$path"`）
> 5. 每个 Step 的 Windows 命令与 macOS/Linux **输出格式不同**，请严格使用对应平台的命令
> 6. **不再支持 CMD**：CMD 没有现代 quoting 能力，所有 Windows 命令请在 PowerShell 中执行
> 7. **临时文件命名一律带 `$fhash` 后缀**（如 `popo_fname_$fhash.txt`、`popo_msgParam_$fhash.json`）—— 保证并发批量发送时不互相覆盖；Step 4 与 Step 5 均用 `try/finally` / `try/catch` 包裹，保证 popo-cli 异常 / Ctrl+C 下也能清理临时文件，避免泄漏

## 前置条件

- 已确定接收方：
  - 用户直接提供 `xxx@corp.netease.com` 或 `xxx@mesg.corp.netease.com` 格式的 POPO 账号 → 直接作为 uid 使用
  - 用户提供人名 → P2P 用 `popo_userinfo_search` 获取 uid；群聊用 `popo_team_search` 获取 tid
- 用户已提供要发送的文件**本地路径**（支持批量）

## Step 1: 获取文件元信息

对**每个**文件，获取以下信息：

| 变量 | 说明 | 示例 |
|------|------|------|
| `fsize` | 文件大小（字节） | `261487` |
| `fhash` | MD5 哈希（hex） | `d3a2372ea56c232094474a18744de017` |
| `fname` | 文件名（含扩展名） | `report.pdf` |
| `fext` | 文件扩展名（不含 `.`） | `pdf` |

根据当前操作系统选择对应命令：

### macOS

```bash
fsize=$(stat -f%z "{file_path}") && fhash=$(md5 -q "{file_path}") && fname=$(basename "{file_path}") && fext="${fname##*.}" && echo "$fsize $fhash $fname $fext"
```

### Linux

```bash
fsize=$(stat -c%s "{file_path}") && fhash=$(md5sum "{file_path}" | awk '{print $1}') && fname=$(basename "{file_path}") && fext="${fname##*.}" && echo "$fsize $fhash $fname $fext"
```

### Windows (PowerShell)

> ⚠️ **中文文件名编码问题**：Windows PowerShell 默认控制台编码为 GBK，`Write-Output` 输出中文**必然乱码**，且 `[Console]::OutputEncoding = UTF8` **无法彻底解决**。
>
> **解决方案**：`fname`（文件名，可能含中文）**不通过 stdout 输出**，改为写入 `$env:TEMP\popo_fname_<fhash>.txt`（UTF-8 无 BOM 临时文件）。stdout 仅输出 `fsize`、`fhash`、`fext`（纯 ASCII，不受编码影响）。后续 Step 4、Step 5 用 `$fhash` 拼出同名路径直接读取。
>
> ⚠️ **临时文件名使用 `popo_fname_<fhash>.txt`** —— `fhash` 是文件内容 MD5（hex），具有以下特性：
> - 跨进程稳定：每个 popo-cli 调用都是独立 PowerShell 进程，fhash 通过 stdout 在步骤间传递
> - 天然唯一：不同文件 fhash 不同 → 并发批量发送多个文件**不会互相覆盖**
> - 纯 ASCII：filename 安全，shell 不会出错

```powershell
$f = Get-Item "{file_path}"; $fsize = $f.Length; $fhash = (Get-FileHash "{file_path}" -Algorithm MD5).Hash.ToLower(); $fext = $f.Extension.TrimStart('.'); [System.IO.File]::WriteAllText((Join-Path $env:TEMP "popo_fname_$fhash.txt"), $f.Name, [System.Text.UTF8Encoding]::new($false)); Write-Output "$fsize $fhash $fext"
```

> **⚠️ Windows 下 stdout 输出为 3 个值（`fsize fhash fext`），不含 `fname`。** `fname` 存储在 `$env:TEMP\popo_fname_<fhash>.txt` 中，由 Step 4 和 Step 5 读取。请勿尝试从 stdout 解析 fname。
>
> **⚠️ Step 2 / 3 / 4 任何一步失败时**，必须用 `Remove-Item -Path (Join-Path $env:TEMP "popo_fname_$fhash.txt") -ErrorAction SilentlyContinue` 清理 fname 临时文件，避免泄漏。详见文末"错误处理"章节。

> **平台判断**：根据执行环境自动选择对应命令。macOS/Linux 输出 4 个值（fname 在 stdout），Windows 输出 3 个值 + 临时文件 `popo_fname_<fhash>.txt`。

## Step 2: 获取 S3 上传地址

使用 Step 1 的 `fsize` 和 `fhash` 调用 `popo_message_s3_ufile_upload`：

```bash
popo-cli popo message_s3_ufile_upload fsize={fsize} fhash={fhash}
```

### 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `fsize` | Integer | **是** | 文件大小（字节）。示例：`1048576` = 1MB |
| `fhash` | String | **是** | 文件 MD5 哈希值，用于校验和去重（秒传） |

### 返回值

返回 JSON 路径为 `data.data.data.data.data`（五层嵌套），包含：

```json
{
  "bucketName": "popo-nos-dev01",
  "url": "https://popo-nos-dev01.s3v2.nie.netease.com/{objectKey}?AWSAccessKeyId=xxx&Expires=xxx&Signature=xxx",
  "objectKey": "4c56f916ee9dca2e6c2ed44242b4bfd2"
}
```

| 字段 | 说明 |
|------|------|
| `url` | S3 预签名上传地址（认证信息已包含在 URL query params 中，无需额外 header） |
| `objectKey` | 文件在存储桶中的唯一标识 |
| `bucketName` | 存储桶名称 |

提取 `url` 字段用于 Step 3 上传，提取 `objectKey` 和 `bucketName` 字段用于 Step 4 上报和 Step 5 组装消息。

> 批量发送时，每个文件需**单独调用一次** Step 1 + Step 2。

## Step 3: 上传文件

使用 **`curl -T`**（PUT upload-file）将文件上传到 Step 2 获取的预签名地址。

⚠️ **必须用 `-T`（PUT），不能用 `--data-binary`（POST）**，否则签名校验失败。

URL 中已包含认证参数（AWSAccessKeyId、Signature），**无需额外 Authorization header**。

### macOS / Linux

```bash
curl -s -w "%{http_code}" -T "{file_path}" "{url}"
```

### Windows (PowerShell)

> ⚠️ **必须使用 `curl.exe`**：PowerShell 中 `curl` 是 `Invoke-WebRequest` 的别名，参数格式不兼容，会导致 `ParameterBindingException`。使用 `curl.exe` 可直接调用系统自带的 curl 二进制文件。

```powershell
curl.exe -s -w "%{http_code}" -T "{file_path}" "{url}"
```

> - `{url}` 替换为 Step 2 返回的 `url` 字段值
> - `{file_path}` 替换为用户提供的本地文件路径

### 成功判定

- HTTP 200 = 上传成功（**无响应 body**，仅凭状态码判断）
- HTTP 非 200 = 上传失败（响应 body 为 XML 错误信息）

## Step 4: 上报上传完成

上传成功后，调用 `popo_message_s3_ufile_upload_complete` 上报本次上传，获取 `ufid`（文件 ID）和 `ftype`（文件类型）用于后续消息发送。

### macOS / Linux

```bash
popo-cli popo message_s3_ufile_upload_complete fsize={fsize} fhash={fhash} objectKey={objectKey} fname={fname} bucketName={bucketName} clientType=3
```

### Windows (PowerShell)

> ⚠️ **fname 临时文件已在 Step 1 创建**：`$env:TEMP\popo_fname_<fhash>.txt`（UTF-8 无 BOM，fhash 由 Step 1 stdout 提供）。此处直接复用，通过 `=@text:` 传给 popo-cli，绕过 shell GBK 编码问题。
>
> ⚠️ **`@text:` 路径必须用双引号包裹**（`"@text:$path"`），否则路径含空格、`&`、`(`、`)`、中文时会被 shell 拆参数。
>
> **禁止**重新从 `$fname` 变量写入临时文件 —— Step 1 的 stdout 不含 fname，`$fname` 变量不存在或为乱码。

```powershell
# fname 临时文件已在 Step 1 创建（路径：$env:TEMP\popo_fname_<fhash>.txt），此处只读不删（Step 5 仍需使用）
$fnameTmpFile = Join-Path $env:TEMP "popo_fname_$fhash.txt"

try {
    popo-cli popo message_s3_ufile_upload_complete fsize=$fsize fhash=$fhash objectKey=$objectKey fname="@text:$fnameTmpFile" bucketName=$bucketName clientType=3
}
catch {
    # Step 4 失败时清理 fname 临时文件后再抛出（避免泄漏）
    Remove-Item -Path $fnameTmpFile -ErrorAction SilentlyContinue
    throw
}
# 注意：成功路径**不删除** $fnameTmpFile，Step 5 还要读取它
```

> **⚠️ 与其它 Step 不同**：Step 4 成功时**不清理** fname 临时文件，因为 Step 5 还要读。**只有失败路径才清理**，避免泄漏。Step 5 最终统一清理。

### 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `fsize` | Integer | **是** | 文件大小（字节），来自 Step 1 |
| `fhash` | String | **是** | 文件 MD5 哈希（hex），来自 Step 1 |
| `objectKey` | String | **是** | S3 存储对象标识，来自 Step 2 |
| `fname` | String | **是** | 文件名（含扩展名），来自 Step 1 |
| `bucketName` | String | **是** | 存储桶名称，来自 Step 2 |
| `clientType` | Integer | **是** | 固定值 `3` |

### 返回值

从响应中提取以下字段：

| 字段 | 说明 | 用途 |
|------|------|------|
| `ufid` | 文件唯一标识 | 作为 Step 5 消息 JSON 中的 `fileID` |
| `ftype` | 文件类型标识 | 作为 Step 5 消息 JSON 中的 `externType` |

> 批量发送时，每个文件需**单独调用一次** Step 4。

## Step 5: 发送消息

上报完成后，构造文件信息 JSON 作为 `message` 参数，`msgType` 传 3。

### message JSON 格式

使用 Step 1、Step 2 和 Step 4 的结果组装：

```json
{
  "fileID": "{ufid}",
  "md5": "{fhash}",
  "format": "{fext}",
  "artwork": "",
  "size": {fsize},
  "type": 3,
  "externType": {ftype},
  "objectKey": "{objectKey}",
  "name": "{fname}"
}
```

| 字段 | 来源 | 说明 |
|------|------|------|
| `md5` | Step 1 的 `fhash` | MD5 哈希（hex） |
| `format` | Step 1 的 `fext` | 文件扩展名（不含 `.`） |
| `size` | Step 1 的 `fsize` | 文件大小（字节，**整数**） |
| `name` | Step 1 的 `fname` | 文件名（含扩展名） |
| `objectKey` | Step 2 返回的 `objectKey` | S3 存储对象标识 |
| `type` | 固定值 `3` | 文件消息类型 |
| `fileID` | Step 4 返回的 `ufid` | 文件唯一标识 |
| `artwork` | 固定空字符串 `""` | — |
| `externType` | Step 4 返回的 `ftype` | 文件类型标识 |

> ⚠️ `message` 参数的值是上述 JSON **序列化后的字符串**（单行、无多余空白）。
>
> **关键：`message` 必须传 JSON 字符串，而非 JSON 对象。** `popo-cli key=value` 传参时，如果值形如 `{...}` 会被当作 JSON 对象发送，导致服务端报错 `Cannot deserialize value of type java.lang.String from Object value`。

### 使用 `=@text:` 文件传参（所有平台统一方式）

将 message JSON 写入临时文件，再用 `=@text:` 传给 popo-cli。popo-cli 读取文件内容作为**纯文本字符串**发送（区别于 `=@file:` 会解析为 JSON 对象），同时规避 shell 引号转义和中文编码问题。

> 📐 **统一架构（所有平台）**
>
> ```text
> 构造结构化对象 → 序列化为 JSON 字符串 → 写入 UTF-8 无 BOM 临时文件 → message="@text:文件路径"
> ```
>
> Shell 只负责"传文件路径"，**不参与 JSON 构造、转义或编码**。这是跨平台稳定的唯一方案。

#### macOS / Linux

> 使用 `python3 -c` 通过结构化对象 + `json.dumps` 生成 JSON，避免 `printf '%s'` 在文件名含 `"`、`\`、换行时的拼接错误。
>
> **`trap` 是强制的**：保证 python3 失败 / popo-cli 异常 / 用户 Ctrl+C 任何场景下都能清理 `$msgTmpFile`，避免泄漏到 `/tmp`。

```bash
# Step 5a: 创建临时文件 + 设置清理 trap（EXIT 兜底正常退出，INT/TERM 兜底信号中断）
msgTmpFile=$(mktemp)
trap 'rm -f "$msgTmpFile"' EXIT INT TERM

# Step 5a (续): 用 python 把结构化字段序列化为合法 JSON 文件（UTF-8 无 BOM）
FILEID="{ufid}" MD5="{fhash}" FORMAT="{fext}" SIZE="{fsize}" EXTERNTYPE="{ftype}" OBJECTKEY="{objectKey}" FNAME="{fname}" \
python3 -c 'import json, os, sys
obj = {
  "fileID": os.environ["FILEID"],
  "md5": os.environ["MD5"],
  "format": os.environ["FORMAT"],
  "artwork": "",
  "size": int(os.environ["SIZE"]),
  "type": 3,
  "externType": int(os.environ["EXTERNTYPE"]),
  "objectKey": os.environ["OBJECTKEY"],
  "name": os.environ["FNAME"],
}
sys.stdout.write(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))' > "$msgTmpFile"

# Step 5b: P2P 发送（@text: 路径必须用双引号包裹）
popo-cli popo message_send_p2p message="@text:$msgTmpFile" receiver=zhangsan@example.com msgType=3 source=AGENT

# Step 5b（群聊）: 群聊发送
popo-cli popo message_send_team message="@text:$msgTmpFile" receiver=group_123 msgType=3 source=AGENT

# Step 5c: 显式清理 + 取消 trap（trap 已在 EXIT 时兜底，这里显式删除是为了立即释放，并清理 trap 注册）
rm -f "$msgTmpFile"
trap - EXIT INT TERM
```

> **没有 python3 时的兜底**：如果环境无 `python3`，可用 `node -e` 或 `jq -n` 同样以"对象 → JSON 字符串"方式生成；**严禁使用 `printf '{"k":"%s"}' "$v"` 式手工拼接**——值含 `"` 或换行就会损坏 JSON。
>
> **批量发送时**：每个文件独立一段 `mktemp + trap + ... + rm + trap -`，**不要把多个文件共用一个 `trap`** —— 否则前一个文件的 trap 清不到后一个文件。

#### Windows (PowerShell)

> 🔒 **铁律：禁止手工拼 JSON**
>
> Windows 平台构造 message JSON **必须**遵守以下四步，任何偏离都会在文件名含 `"`、`\`、换行、`&` 等字符时炸掉：
>
> 1. **构造哈希表对象**（`@{ ... }`）—— 字段名、字段值都用 PowerShell 原生类型，不碰任何引号
> 2. **`ConvertTo-Json -Compress`** 序列化为合法 JSON 字符串
> 3. **`[System.IO.File]::WriteAllText(..., [System.Text.UTF8Encoding]::new($false))`** 写入 UTF-8 **无 BOM** 文件
> 4. **`message="@text:$path"`** 传给 popo-cli，**路径必须用双引号包裹**
>
> ❌ **严禁**：
> - 手工字符串拼接 JSON（`'{"fileID":"' + $ufid + '"}'`）
> - 用 `\"` 转义 JSON 双引号
> - 用 `Set-Content -Encoding UTF8`（PS 5.1 写 BOM）/ `Out-File`（默认 UTF-16）
> - 用 `powershell -Command "..."` 包裹再传 JSON
> - 在 CMD 中执行此流程
>
> ✅ `ConvertTo-Json` 把中文转义为 `\uXXXX` 是 **JSON 标准合法行为**，服务端等价解析，**不要回避**。真正会出问题的是 BOM、shell quoting、非 UTF-8、非法 JSON。

```powershell
# Step 5a: 用 fhash 拼出 fname 临时文件路径（Step 1 已创建，UTF-8 无 BOM）
$fnameTmpFile = Join-Path $env:TEMP "popo_fname_$fhash.txt"
# msgParam JSON 也用 fhash 后缀，保证批量发送时不互相覆盖
$msgTmpFile   = Join-Path $env:TEMP "popo_msgParam_$fhash.json"

try {
    # 读取 fname（Step 1 写入的 UTF-8 无 BOM 文件）
    $fname = [System.IO.File]::ReadAllText($fnameTmpFile, [System.Text.UTF8Encoding]::new($false))

    # 1) 构造结构化对象（字段值是原生 PS 类型，不参与引号/转义）
    $msgObj = [ordered]@{
        fileID     = [string]$ufid
        md5        = [string]$fhash
        format     = [string]$fext
        artwork    = ''
        size       = [int64]$fsize
        type       = 3
        externType = [int]$ftype
        objectKey  = [string]$objectKey
        name       = [string]$fname
    }

    # 2) 序列化为合法单行 JSON（中文会被转为 \uXXXX，这是 JSON 标准合法形式，服务端等价解析）
    $msgJson = $msgObj | ConvertTo-Json -Compress

    # 3) 写入 UTF-8 无 BOM 临时文件（务必用 WriteAllText，禁止 Set-Content / Out-File）
    [System.IO.File]::WriteAllText($msgTmpFile, $msgJson, [System.Text.UTF8Encoding]::new($false))

    # Step 5b: 4) 通过 @text: 传文件路径（路径必须双引号包裹，防止空格/中文/特殊字符拆参数）
    # P2P 发送
    popo-cli popo message_send_p2p message="@text:$msgTmpFile" receiver=zhangsan@example.com msgType=3 source=AGENT

    # 群聊发送
    popo-cli popo message_send_team message="@text:$msgTmpFile" receiver=group_123 msgType=3 source=AGENT
}
finally {
    # Step 5c: 无条件清理所有临时文件（包括 Step 1 创建的 fname 文件 + Step 5a 创建的 msgParam 文件）
    Remove-Item -Path $fnameTmpFile, $msgTmpFile -ErrorAction SilentlyContinue
}
```

> **批量发送**：每个文件按 Step 5a → 5b → 5c 顺序逐个处理。**每个文件 try/finally 独立一段**，不要把多个文件挤在同一个 try 里 —— 否则前一个文件失败会导致后续文件不执行；且 `$fhash` 不同保证临时文件名不互相覆盖。
>
> **自检要点**（Windows）：
> - 写文件前打印 `$msgJson`，确认形如 `{"fileID":"...","md5":"...",...,"name":"..."}` 单行 JSON，**不含**字面 `\"` 或前导 `\ufeff`
> - popo-cli 调用行的 `message` 必须是 `message="@text:$msgTmpFile"`（带双引号），**不是** `message=@text:$msgTmpFile`
> - **`try/finally` 是强制的**：`finally` 块保证 popo-cli 抛错 / 用户 Ctrl+C / `$ErrorActionPreference='Stop'` 任何场景下都清理 fname + msgParam 两个文件

## 典型场景

```
用户："帮我给张三发一个文件 /Users/xxx/report.pdf"
  ├─ Step 0: popo_userinfo_search("张三") → zhangsan@example.com
  ├─ Step 1: stat + md5 + basename → fsize=1048576, fhash="d41d8cd98f00b204e9800998ecf8427e", fname="report.pdf", fext="pdf"
  ├─ Step 2: popo-cli popo message_s3_ufile_upload fsize=1048576 fhash=d41d8cd98f00b204e9800998ecf8427e
  │          → url="https://popo-nos-dev01.s3v2.nie.netease.com/xxx?AWSAccessKeyId=...&Signature=...", objectKey="4c56f916ee9dca2e6c2ed44242b4bfd2", bucketName="popo-nos-dev01"
  ├─ Step 3: curl -s -w "%{http_code}" -T "/Users/xxx/report.pdf" "{url}" → 200
  ├─ Step 4: popo-cli popo message_s3_ufile_upload_complete fsize=1048576 fhash=d41d8cd98f00b204e9800998ecf8427e objectKey=4c56f916ee9dca2e6c2ed44242b4bfd2 fname=report.pdf bucketName=popo-nos-dev01 clientType=3
  │          → ufid="abc123", ftype=1
  └─ Step 5: 写入临时文件 → popo-cli popo message_send_p2p message="@text:$tmpFile" receiver=zhangsan@example.com msgType=3 source=AGENT
```

```
用户："在项目群里发两个附件 ~/a.docx ~/b.xlsx"
  ├─ Step 0: popo_team_search("项目群") → tid=group_456
  ├─ Step 1: 分别获取两个文件的 fsize、fhash、fname、fext
  ├─ Step 2a: popo-cli popo message_s3_ufile_upload fsize={fsize_a} fhash={fhash_a} → url_1, objectKey_1, bucketName_1
  ├─ Step 2b: popo-cli popo message_s3_ufile_upload fsize={fsize_b} fhash={fhash_b} → url_2, objectKey_2, bucketName_2
  ├─ Step 3a: curl -T ~/a.docx "{url_1}" → 200
  ├─ Step 3b: curl -T ~/b.xlsx "{url_2}" → 200
  ├─ Step 4a: popo-cli popo message_s3_ufile_upload_complete fsize={fsize_a} fhash={fhash_a} objectKey={objectKey_1} fname=a.docx bucketName={bucketName_1} clientType=3 → ufid_1, ftype_1
  ├─ Step 4b: popo-cli popo message_s3_ufile_upload_complete fsize={fsize_b} fhash={fhash_b} objectKey={objectKey_2} fname=b.xlsx bucketName={bucketName_2} clientType=3 → ufid_2, ftype_2
  ├─ Step 5a: 写入临时文件 → popo-cli popo message_send_team message="@text:$tmpFile" receiver=group_456 msgType=3 source=AGENT
  └─ Step 5b: 写入临时文件 → popo-cli popo message_send_team message="@text:$tmpFile" receiver=group_456 msgType=3 source=AGENT
```

## 错误处理

| 阶段 | 失败条件 | 处理方式 |
|------|---------|---------|
| Step 1 | 文件不存在或无读取权限 | 报告文件路径无效，终止流程（Step 1 失败时 fname 临时文件还未创建，无需清理） |
| Step 2 | `popo-cli` 返回错误 | 报告错误信息给用户，**Windows 平台清理 `$env:TEMP\popo_fname_$fhash.txt`**，终止流程 |
| Step 3 | curl 返回非 200 | 报告上传失败，附带 XML 错误信息，**Windows 平台清理 `$env:TEMP\popo_fname_$fhash.txt`** |
| Step 4 | `popo-cli` 返回错误 | 报告上报失败，附带错误信息，**Windows 平台清理 `$env:TEMP\popo_fname_$fhash.txt`**（Step 4 的 try/catch 已自动清理），终止流程 |
| Step 5 | 消息发送失败 | 报告发送失败，附带错误信息（Step 5 的 try/finally 已自动清理两个临时文件，无需额外操作） |
| 批量 | 部分文件上传失败 | 发送已成功上传的文件，报告失败的文件列表；**每个失败文件单独清理其 `popo_fname_$fhash.txt`** |

### Windows 临时文件清理 cheat sheet

如果在 Step 2 / 3 / 4 任何中间步骤失败，且对应的 fname 临时文件**已被 Step 1 创建但尚未被 Step 5 清理**，必须手动清理：

```powershell
Remove-Item -Path (Join-Path $env:TEMP "popo_fname_$fhash.txt") -ErrorAction SilentlyContinue
```

> ⚠️ **不要**直接 `Remove-Item $env:TEMP\popo_fname_*.txt`（通配清理）—— 这会误删**正在进行中的其他并发文件发送**的 fname 文件，导致那些操作失败。**只清理本次失败的 `$fhash` 对应的那个文件**。

### macOS / Linux 临时文件清理

macOS / Linux 在 Step 5 中通过 `trap 'rm -f "$msgTmpFile"' EXIT INT TERM` 自动清理 `$(mktemp)` 创建的临时文件，**正常退出、信号中断、Ctrl+C 都能保证清理**，无需额外操作。Step 1～4 在 macOS / Linux 上不创建临时文件（fname 走 stdout），失败时无需清理。
