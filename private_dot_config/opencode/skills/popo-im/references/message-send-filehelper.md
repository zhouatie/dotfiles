# popo_message_send_filehelper

向文件传输助手发送消息（即发送给自己）。支持纯文本、图片和文件。

> **何时使用**：当用户提到"发送给文件传输助手"、"发给自己"、"发到文件助手"等意图时，使用此工具。无需查询用户，直接发送。

## 命令

> 🪟 **Windows 平台必读**：所有 `message` 参数（纯文本 / `[img]` / 文件 JSON）**强制走 `@text:` 临时文件**，不得在 shell 中直接传字符串。下方 macOS / Linux 示例**仅适用于 macOS / Linux**，Windows 一律参见后续 "Windows (PowerShell)" 段落。

### macOS / Linux

```bash
# 发送纯文本消息（默认）
popo-cli popo message_send_filehelper message=你好 source=AGENT

# 发送包含空格的消息（用引号包裹）
popo-cli popo message_send_filehelper message="这是一条备忘消息" source=AGENT

# 发送图片消息（纯文本方式，[img] 标签包裹 FP 地址）
popo-cli popo message_send_filehelper message="[img]http://fp.example.com/test.png[/img]" source=AGENT

# 发送文件消息（msgType=3，message 为文件信息 JSON 字符串）
# ⚠️ message 值必须是 JSON 字符串（双重转义），不能是 JSON 对象，否则服务端报错
# 跨平台（macOS / Linux / Windows）: 使用 =@text: 临时文件方式
# popo-cli popo message_send_filehelper message=@text:$tmpFile msgType=3 source=AGENT
# 详见 message-send-file-workflow.md 的 Step 5
```

### Windows (PowerShell)

> ⚠️ **铁律**：`message` 参数**必须**通过 UTF-8 无 BOM 临时文件 + `@text:` 传递。
>
> ⚠️ **GBK 编码陷阱**：PowerShell 5.1 读取不含 UTF-8 BOM 的 `.ps1` 文件时按系统 ANSI（GBK）解析源码，导致全角字符（`（）` `《》` `【】` `，。` 等）在脚本解析阶段损坏——`$msgContent` 拿到时已经是乱码。**`.ps1` 文件必须保存为 UTF-8 with BOM**。若写入工具无法直接指定 BOM，用以下方式创建：
> ```bash
> printf '\xEF\xBB\xBF' > script.ps1
> cat >> script.ps1 << 'PSEOF'
> ```
> 纯 ASCII 内容（如 `[img]` 标签）不受此影响。

```powershell
# === 纯文本消息 ===
$msgContent = "这是一条备忘消息"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo message_send_filehelper message="@text:$msgTmpFile" source=AGENT
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}

# === 图片消息（[img] 标签包裹 FP 地址）===
$msgContent = "[img]http://fp.example.com/test.png[/img]"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo message_send_filehelper message="@text:$msgTmpFile" source=AGENT
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}

# === 文件消息（msgType=3）===
# message JSON 的构造与写入流程详见 message-send-file-workflow.md 的 Step 5
# popo-cli popo message_send_filehelper message="@text:$msgTmpFile" msgType=3 source=AGENT
```

> **`try/finally` 是强制的**：保证 popo-cli 抛错 / 用户 Ctrl+C / `$ErrorActionPreference='Stop'` 任何场景下临时文件都会被清理。

## 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `message` | String | **是** | 消息内容。纯文本直接填写；图片用 `[img]FP地址[/img]` 包裹；文件填文件信息 JSON 字符串（详见 [message-send-file-workflow.md](message-send-file-workflow.md)） |
| `msgType` | Integer | 否 | 消息类型，**仅允许 `1` 或 `3`**：`1`=纯文本（默认），`3`=S3 文件。⚠️ **发送纯文本或图片时，直接省略此参数，不要传 `msgType=0` 或任何非 1/3 的值，否则接口报错。** 只有发送文件时才需要显式传 `msgType=3` |
| `source` | String | **是** | 固定值 `AGENT`，标记消息来源于 Agent 发送 |

> ⚠️ **此工具无 `receiver` 参数**。接收方固定为当前用户的文件传输助手，由服务端自动处理。

## 消息类型说明

| 类型 | msgType | message 内容 | 上传流程 |
|------|---------|-------------|---------|
| **纯文本** | 1（默认） | 文本内容 | 无需上传 |
| **图片** | 1（默认） | `[img]FP地址[/img]` | 读取 [message-send-image-workflow.md](message-send-image-workflow.md) |
| **文件** | 3 | 文件信息 JSON 字符串 | 读取 [message-send-file-workflow.md](message-send-file-workflow.md) |

## 使用要点

### 发送流程

1. **无需解析接收方**：文件传输助手是固定目标，无需调用 `popo_userinfo_search`
2. **判断消息类型**：
   - 纯文本 → 直接调用发送
   - 图片 → 读取 [message-send-image-workflow.md](message-send-image-workflow.md) 执行上传流程
   - 文件 → 读取 [message-send-file-workflow.md](message-send-file-workflow.md) 执行上传流程
3. **调用发送**：直接调用 `popo_message_send_filehelper`
4. **结果反馈**：告知用户消息已发送到文件传输助手

### 典型场景

```
用户："帮我发一条消息给文件传输助手，内容是明天记得开会"
  └─ Step 1: popo_message_send_filehelper(message="明天记得开会")
```

```
用户："发给自己一条备忘：下周一提交报告"
  └─ Step 1: popo_message_send_filehelper(message="下周一提交报告")
```

```
用户："把这张图发给文件传输助手 ~/screenshot.png"
  └─ Step 1: 执行 message-send-image-workflow.md 流程（上传 → 组装 [img] 标签 → popo_message_send_filehelper 发送）
```

```
用户："发个文件给自己 ~/report.pdf"
  └─ Step 1: 执行 message-send-file-workflow.md 流程（上传 → 上报完成 → popo_message_send_filehelper(msgType=3) 发送）
```
