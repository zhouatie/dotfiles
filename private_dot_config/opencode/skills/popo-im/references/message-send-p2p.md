# popo_message_send_p2p

向指定用户发送 P2P（单聊）消息。支持纯文本、图片和文件。

## 命令

> 🪟 **Windows 平台必读**：所有 `message` 参数（纯文本 / `[img]` / 文件 JSON）**强制走 `@text:` 临时文件**，不得在 shell 中直接传字符串。下方 macOS / Linux 示例**仅适用于 macOS / Linux**，Windows 一律参见后续 "Windows (PowerShell)" 段落。

### macOS / Linux

```bash
# 发送纯文本消息（默认）
popo-cli popo message_send_p2p message=你好 receiver=zhangsan@example.com source=AGENT

# 发送包含空格的消息（用引号包裹）
popo-cli popo message_send_p2p message="明天下午3点开会，请准时参加" receiver=zhangsan@example.com source=AGENT

# 发送图片消息（纯文本方式，[img] 标签包裹 FP 地址）
popo-cli popo message_send_p2p message="[img]http://fp.example.com/test.png[/img]" receiver=zhangsan@example.com source=AGENT

# 发送文件消息（msgType=3，message 为文件信息 JSON 字符串）
# ⚠️ message 值必须是 JSON 字符串（双重转义），不能是 JSON 对象，否则服务端报错
# 跨平台（macOS / Linux / Windows）: 使用 =@text: 临时文件方式
# popo-cli popo message_send_p2p message=@text:$tmpFile receiver=zhangsan@example.com msgType=3 source=AGENT
# 详见 message-send-file-workflow.md 的 Step 5
```

### Windows (PowerShell)

> ⚠️ **铁律**：`message` 参数**必须**通过 UTF-8 无 BOM 临时文件 + `@text:` 传递。即使内容看起来"很安全"（纯 ASCII 短文本）也必须遵守，避免 shell 切换带来的隐性损坏。
>
> ⚠️ **绝不允许**直接 `message="..."` 在 PowerShell 中传字符串 —— 含中文必乱码（GBK），含 `&`/`(`/`)`/空格 在不同 shell 下行为不一致。
>
> ⚠️ **GBK 编码陷阱**：PowerShell 5.1 读取不含 UTF-8 BOM 的 `.ps1` 文件时按系统 ANSI（GBK）解析源码，导致全角字符（`（）` `《》` `【】` `，。` 等）在脚本解析阶段损坏——`$msgContent` 拿到时已经是乱码。**`.ps1` 文件必须保存为 UTF-8 with BOM**。若写入工具无法直接指定 BOM，用以下方式创建：
> ```bash
> printf '\xEF\xBB\xBF' > script.ps1
> cat >> script.ps1 << 'PSEOF'
> ```
> 纯 ASCII 内容（如 `[img]` 标签）不受此影响。

```powershell
# === 纯文本消息 ===
$msgContent = "明天下午3点开会，请准时参加"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo message_send_p2p message="@text:$msgTmpFile" receiver=zhangsan@example.com source=AGENT
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}

# === 图片消息（[img] 标签包裹 FP 地址，FP url 通常含 & 必须走 @text:） ===
$msgContent = "[img]http://fp.example.com/test.png[/img]"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo message_send_p2p message="@text:$msgTmpFile" receiver=zhangsan@example.com source=AGENT
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}

# === 文件消息（msgType=3）===
# message JSON 的构造与写入流程详见 message-send-file-workflow.md 的 Step 5
# popo-cli popo message_send_p2p message="@text:$msgTmpFile" receiver=zhangsan@example.com msgType=3 source=AGENT
```

> **自检要点**：
> - `message=` 后必须是 `"@text:$msgTmpFile"`（带双引号），不是 `@text:$msgTmpFile`（不带引号）—— 否则路径含空格或中文用户名时炸
> - 写文件**必须**用 `[System.IO.File]::WriteAllText(..., [System.Text.UTF8Encoding]::new($false))`，不得用 `Set-Content -Encoding UTF8`（PS 5.1 写 BOM）或 `Out-File`（默认 UTF-16）
> - 临时文件名带 GUID 后缀，避免并发发送时互相覆盖
> - **`try/finally` 是强制的**：保证 popo-cli 抛错 / 用户 Ctrl+C / `$ErrorActionPreference='Stop'` 任何场景下临时文件都会被清理

## 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `message` | String | **是** | 消息内容。纯文本直接填写；图片用 `[img]FP地址[/img]` 包裹；文件填文件信息 JSON 字符串（详见 [message-send-file-workflow.md](message-send-file-workflow.md)） |
| `receiver` | String | **是** | 接收方用户 uid（POPO 账号，格式为 `xxx@corp.netease.com` 或 `xxx@mesg.corp.netease.com`）。**任何包含 `@` 的邮箱格式地址都是个人账号**（包括 `grp.xxx@corp.netease.com` 等特殊前缀账号），直接用作 receiver。用户提供人名时通过 `popo_userinfo_search` 获取；用户直接提供 POPO 账号时直接使用 |
| `msgType` | Integer | 否 | 消息类型，**仅允许 `1` 或 `3`**：`1`=纯文本（默认），`3`=S3 文件。⚠️ **发送纯文本或图片时，直接省略此参数，不要传 `msgType=0` 或任何非 1/3 的值，否则接口报错。** 只有发送文件时才需要显式传 `msgType=3` |
| `source` | String | **是** | 固定值 `AGENT`，标记消息来源于 Agent 发送 |

## 消息类型说明

| 类型 | msgType | message 内容 | 上传流程 |
|------|---------|-------------|---------|
| **纯文本** | 1（默认） | 文本内容 | 无需上传 |
| **图片** | 1（默认） | `[img]FP地址[/img]` | 读取 [message-send-image-workflow.md](message-send-image-workflow.md) |
| **文件** | 3 | 文件信息 JSON 字符串 | 读取 [message-send-file-workflow.md](message-send-file-workflow.md) |

## 使用要点

### 发送流程

1. **解析接收方**：
   - 用户直接提供 `xxx@corp.netease.com` 或 `xxx@mesg.corp.netease.com` 格式的 POPO 账号 → **直接用作 receiver**，无需搜索
   - 用户提到人名（如"张三"）→ 通过 `popo_userinfo_search` 获取 uid，**不要猜测**
2. **判断消息类型**：
   - 纯文本 → 直接调用发送
   - 图片 → 读取 [message-send-image-workflow.md](message-send-image-workflow.md) 执行上传流程
   - 文件 → 读取 [message-send-file-workflow.md](message-send-file-workflow.md) 执行上传流程
3. **调用发送**：使用接收方 uid 和消息内容调用 `popo_message_send_p2p`
4. **结果反馈**：告知用户消息已发送

### 典型场景

```
用户："帮我给张三发条消息，说明天下午开会"
  ├─ Step 1: popo_userinfo_search("张三") → zhangsan@example.com
  └─ Step 2: popo_message_send_p2p(message="明天下午开会", receiver="zhangsan@example.com")
```

```
用户："帮我给 yuexichun@corp.netease.com 发条消息，说明天下午开会"
  └─ Step 1: popo_message_send_p2p(message="明天下午开会", receiver="yuexichun@corp.netease.com")
  （用户直接提供了 POPO 账号，无需 popo_userinfo_search）
```

```
用户："帮我发送消息给 grp.popoqa123@corp.netease.com"
  └─ Step 1: popo_message_send_p2p(message="...", receiver="grp.popoqa123@corp.netease.com")
  （grp. 开头但是邮箱格式 → 个人特殊账号，走 P2P 单聊，不是群组）
```

```
用户："帮我给张三发一张图片 ~/screenshot.png"
  ├─ Step 1: popo_userinfo_search("张三") → zhangsan@example.com
  └─ Step 2: 执行 message-send-image-workflow.md 流程（上传 → 组装 [img] 标签 → 发送）
```

```
用户："帮我给张三发个文件 ~/report.pdf"
  ├─ Step 1: popo_userinfo_search("张三") → zhangsan@example.com
  └─ Step 2: 执行 message-send-file-workflow.md 流程（上传 → 上报完成 → msgType=3 发送）
```
