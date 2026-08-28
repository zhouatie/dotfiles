# popo_message_send_team

向指定群组发送消息。支持纯文本、图片和文件。纯文本和图片消息支持 @人。

## 命令

> 🪟 **Windows 平台必读**：所有 `message` 参数（纯文本 / `[img]` / 文件 JSON）**强制走 `@text:` 临时文件**，不得在 shell 中直接传字符串。下方 macOS / Linux 示例**仅适用于 macOS / Linux**，Windows 一律参见后续 "Windows (PowerShell)" 段落。

### macOS / Linux

```bash
# 发送纯文本消息（默认）
popo-cli popo message_send_team message=收到 receiver=group_123 source=AGENT

# 发送包含空格的消息（用引号包裹）
popo-cli popo message_send_team message="明天下午3点开会，请大家准时参加" receiver=group_123 source=AGENT

# 发送图片消息（纯文本方式，[img] 标签包裹 FP 地址）
popo-cli popo message_send_team message="[img]http://fp.example.com/test.png[/img]" receiver=group_123 source=AGENT

# 发送文件消息（msgType=3，message 为文件信息 JSON 字符串）
# ⚠️ message 值必须是 JSON 字符串（双重转义），不能是 JSON 对象，否则服务端报错
# 跨平台（macOS / Linux / Windows）: 使用 =@text: 临时文件方式
# popo-cli popo message_send_team message=@text:$tmpFile receiver=group_123 msgType=3 source=AGENT
# 详见 message-send-file-workflow.md 的 Step 5

# @所有人
popo-cli popo message_send_team message="@所有人 注意了" receiver=group_123 source=AGENT isAtAll=true

# @指定用户（macOS / Linux）
popo-cli popo message_send_team message="这是一条消息 @张三 @李四" receiver=group_123 source=AGENT isAtAll=false atUids="[\"zhangsan@corp.netease.com\",\"lisi@corp.netease.com\"]"

# @所有人 + @指定用户（macOS / Linux）
popo-cli popo message_send_team message="@所有人 这是一条消息 @张三 @李四" receiver=group_123 source=AGENT isAtAll=true atUids="[\"zhangsan@corp.netease.com\",\"lisi@corp.netease.com\"]"
```

### Windows (PowerShell)

> ⚠️ **铁律**：`message` 参数（纯文本 / `[img]` / 文件 JSON）**必须**通过 UTF-8 无 BOM 临时文件 + `@text:` 传递；`atUids` 数组通过 `@file:` 临时文件传递。**绝不允许**在 shell 中直接 `message="..."` 或 `atUids="[\"...\"]"`。
>
> ⚠️ **GBK 编码陷阱**：PowerShell 5.1 读取不含 UTF-8 BOM 的 `.ps1` 文件时按系统 ANSI（GBK）解析源码，导致全角字符（`（）` `《》` `【】` `，。` 等）在脚本解析阶段损坏——`$msgContent` 拿到时已经是乱码。**`.ps1` 文件必须保存为 UTF-8 with BOM**。若写入工具无法直接指定 BOM，用以下方式创建：
> ```bash
> printf '\xEF\xBB\xBF' > script.ps1
> cat >> script.ps1 << 'PSEOF'
> ```
> 纯 ASCII 内容（如 `[img]` 标签、`@所有人`）不受此影响。

```powershell
# === 纯文本消息（无 @）===
$msgContent = "明天下午3点开会，请大家准时参加"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo message_send_team message="@text:$msgTmpFile" receiver=group_123 source=AGENT
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}

# === 图片消息（[img] 标签）===
$msgContent = "[img]http://fp.example.com/test.png[/img]"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo message_send_team message="@text:$msgTmpFile" receiver=group_123 source=AGENT
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}

# === @所有人 ===
$msgContent = "@所有人 注意了"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo message_send_team message="@text:$msgTmpFile" receiver=group_123 source=AGENT isAtAll=true
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}

# === @指定用户（message 走 @text:，atUids 走 @file:）===
$msgContent = "这是一条消息 @张三 @李四"
$atUids = @("zhangsan@corp.netease.com", "lisi@corp.netease.com")
$msgTmpFile     = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
$atUidsTmpFile  = Join-Path $env:TEMP "popo_atUids_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    $atUidsJson = ConvertTo-Json -InputObject $atUids -Compress
    [System.IO.File]::WriteAllText($atUidsTmpFile, $atUidsJson, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo message_send_team message="@text:$msgTmpFile" receiver=group_123 source=AGENT isAtAll=false atUids="@file:$atUidsTmpFile"
}
finally {
    Remove-Item -Path $msgTmpFile, $atUidsTmpFile -ErrorAction SilentlyContinue
}

# === @所有人 + @指定用户 ===
$msgContent = "@所有人 这是一条消息 @张三 @李四"
$atUids = @("zhangsan@corp.netease.com", "lisi@corp.netease.com")
$msgTmpFile     = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
$atUidsTmpFile  = Join-Path $env:TEMP "popo_atUids_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    $atUidsJson = ConvertTo-Json -InputObject $atUids -Compress
    [System.IO.File]::WriteAllText($atUidsTmpFile, $atUidsJson, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo message_send_team message="@text:$msgTmpFile" receiver=group_123 source=AGENT isAtAll=true atUids="@file:$atUidsTmpFile"
}
finally {
    Remove-Item -Path $msgTmpFile, $atUidsTmpFile -ErrorAction SilentlyContinue
}
```

> **关键区别**：
> - `@text:` —— popo-cli 把文件内容**作为字符串**发送（用于 `message`）
> - `@file:` —— popo-cli 把文件内容**解析为 JSON 值**（数组/对象）后发送（用于 `atUids`）
> - 两者不能混用：`message` 是 String 类型必须用 `@text:`，`atUids` 是 Array 类型必须用 `@file:`
>
> **`try/finally` 是强制的**：双文件场景下，即使第二个 `WriteAllText` 失败或 popo-cli 异常退出，`finally` 块仍能用 `Remove-Item -Path $a, $b` 一次清理已创建的文件；`Remove-Item -ErrorAction SilentlyContinue` 会忽略"文件不存在"错误，所以传入未成功创建的路径也是安全的。

## 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `message` | String | **是** | 消息内容。纯文本直接填写；图片用 `[img]FP地址[/img]` 包裹；文件填文件信息 JSON 字符串（详见 [message-send-file-workflow.md](message-send-file-workflow.md)）。需要 @ 时，在正文中插入可见的 @ 文本（如 `@所有人`、`@姓名`） |
| `receiver` | String | **是** | 接收方群组 ID（tid，**纯数字格式**，通过 `popo_team_search` 获取）。⚠️ 邮箱格式的地址（包含 `@`）不是群组 ID，即使以 `grp.` 开头也是个人账号，应走 P2P 单聊 |
| `msgType` | Integer | 否 | 消息类型，**仅允许 `1` 或 `3`**：`1`=纯文本（默认），`3`=S3 文件。⚠️ **发送纯文本或图片时，直接省略此参数，不要传 `msgType=0` 或任何非 1/3 的值，否则接口报错。** 只有发送文件时才需要显式传 `msgType=3` |
| `source` | String | **是** | 固定值 `AGENT`，标记消息来源于 Agent 发送 |
| `isAtAll` | Boolean | 否 | 是否 @所有人。`true` 表示 @所有人（message 中需包含 `@所有人` 可见文本）。仅纯文本和图片消息支持，文件消息不支持 |
| `atUids` | Array\<String\> | 否 | 需要 @的用户 uid 列表。协议层真正用于 @ 提醒的字段，message 中的可见 @ 文本仅用于展示。仅纯文本和图片消息支持，文件消息不支持 |

## @ 功能说明

> ⚠️ **仅纯文本和图片消息（msgType=1）支持 @ 功能，文件消息（msgType=3）不支持。**

### 核心机制

- **`message` 中的 @ 文本**：纯展示用，可以写昵称或姓名，决定消息正文中显示什么
- **`atUids`**：协议层真正触发 @ 提醒通知的字段
- **`isAtAll=true`**：@所有人，优先级高于 `atUids`；两者可同时使用

### @ 场景对照

| 场景 | `isAtAll` | `atUids` | `message` 示例 |
|------|-----------|----------|----------------|
| @所有人 | `true` | 可省略 | `@所有人 注意了` |
| @指定用户 | `false` | 用户 uid 数组 | `这是一条消息 @张三` |
| @所有人 + @指定用户 | `true` | 用户 uid 数组 | `@所有人 这是一条消息 @李四` |

### message 中 @ 文本的写法

message 中 `@` 后面**必须使用 `popo_userinfo_search` 返回的 `content.showName` 字段值**（若 `showName` 为空字符串或不存在，则用 `content.name` 兜底），不能跟邮箱（邮箱不会被客户端解析为 @ 提醒）：

> ⚠️ **禁止直接使用用户输入的名字作为 @ 文本**。即使用户说的名字看起来和 `showName`/`name` 一致，也必须从 `popo_userinfo_search` 返回结果中提取（优先 `content.showName`，为空则 `content.name`），不得跳过取值步骤。

- **@指定用户**：通过 `popo_userinfo_search` 查询后，优先取 `content.showName`（为空则取 `content.name`）拼接为 `@显示名` 写入 message；`content.uid` 放入 `atUids`
- **用户直接提供了 POPO 账号**：仍需通过 `popo_userinfo_search` 查询获取 `content.showName`（或 `content.name`）写入 message 的 @ 文本；账号本身放入 `atUids`
- **@所有人**：固定写 `@所有人`，设置 `isAtAll=true`

> ⚠️ **禁止在 message 中写 `@邮箱`**（如 `@zhangsan@corp.netease.com`），这种写法不会被解析，对方收不到 @ 提醒。
>
> ⚠️ **禁止自动邀请不在群内的用户入群**。@ 某人时，如果该用户不在群内，应告知用户该成员不在群中，由用户自行决定是否邀请入群，**不得自行调用 `popo_team_invite` 拉人**。

## 消息类型说明

| 类型 | msgType | message 内容 | 上传流程 | 支持 @ |
|------|---------|-------------|---------|:------:|
| **纯文本** | 1（默认） | 文本内容 | 无需上传 | ✅ |
| **图片** | 1（默认） | `[img]FP地址[/img]` | 读取 [message-send-image-workflow.md](message-send-image-workflow.md) | ✅ |
| **文件** | 3 | 文件信息 JSON 字符串 | 读取 [message-send-file-workflow.md](message-send-file-workflow.md) | ❌ |

## 使用要点

### 发送流程

1. **解析群组**：用户提到群名时，先通过 `popo_team_search` 获取群组 ID（tid），**不要猜测群 ID**
2. **判断消息类型**：
   - 纯文本 → 直接调用发送
   - 图片 → 读取 [message-send-image-workflow.md](message-send-image-workflow.md) 执行上传流程
   - 文件 → 读取 [message-send-file-workflow.md](message-send-file-workflow.md) 执行上传流程
3. **判断是否需要 @**（仅纯文本和图片）：
   - 用户要求 @所有人 → 设置 `isAtAll=true`，message 中加入 `@所有人`
   - 用户要求 @某人 → 通过 `popo_userinfo_search` 查询，将 `content.uid` 放入 `atUids`，**从返回结果中优先取 `content.showName`（为空则取 `content.name`）**（不得直接使用用户输入的名字）拼接为 `@显示名` 写入 message
   - 用户直接提供了 POPO 账号但需要 @ → 账号放入 `atUids`，**仍需查询 `popo_userinfo_search` 获取 `content.showName`（或 `content.name`）写入 message**（禁止 `@邮箱`）
   - @所有人 与 @指定用户可同时使用
4. **调用发送**：使用群组 tid 和消息内容调用 `popo_message_send_team`
5. **结果反馈**：告知用户消息已发送到群

### 典型场景

```
用户："在项目讨论群里发一条消息，说明天的会议推迟到下周"
  ├─ Step 1: popo_team_search("项目讨论群") → tid=group_123
  └─ Step 2: popo_message_send_team(message="明天的会议推迟到下周", receiver="group_123")
```

```
用户："在项目群里 @所有人 说注意了"
  ├─ Step 1: popo_team_search("项目群") → tid=group_123
  └─ Step 2: popo_message_send_team(message="@所有人 注意了", receiver="group_123", isAtAll=true)
```

```
用户："在项目群里 @张三和李四 说明天开会"
  ├─ Step 1: popo_team_search("项目群") → tid=group_123
  ├─ Step 2: popo_userinfo_search("张三") → uid=zhangsan@corp.netease.com, showName=张三（非空，使用 showName）
  ├─ Step 3: popo_userinfo_search("李四") → uid=lisi@corp.netease.com, showName=李四（可与 Step 2 并行）
  └─ Step 4: popo_message_send_team(message="@张三 @李四 明天开会", receiver="group_123", isAtAll=false, atUids=["zhangsan@corp.netease.com","lisi@corp.netease.com"])
```

```
用户："在项目群里 @所有人 再 @张三 说注意查收"
  ├─ Step 1: popo_team_search("项目群") → tid=group_123
  ├─ Step 2: popo_userinfo_search("张三") → uid=zhangsan@corp.netease.com, showName=张三
  └─ Step 3: popo_message_send_team(message="@所有人 @张三 注意查收", receiver="group_123", isAtAll=true, atUids=["zhangsan@corp.netease.com"])
```

```
用户："在项目讨论群 @发布机器人 发个通知，说版本已发布"
  ├─ Step 1: popo_team_search("项目讨论群") → tid=group_123
  ├─ Step 2: popo_userinfo_search("发布机器人") → uid=<机器人 POPO 账号>（includeRobot=true 命中机器人账号）
  └─ Step 3: popo_message_send_team(message="@发布机器人 版本已发布", receiver="group_123", isAtAll=false, atUids=["<机器人 POPO 账号>"])
  （⚠️ 用户以自己身份发送并 @ 机器人，机器人是被提及对象；即使机器人名含"机器人"字样也绝不走 use_robot_send_msg。用户说"at发布机器人"/"艾特发布机器人"同理——at/艾特/＠ 与 @ 等价，均为被提及标志）
```

```
用户："在项目群里发几张截图 ~/a.png ~/b.png"
  ├─ Step 1: popo_team_search("项目群") → tid=group_123
  └─ Step 2: 执行 message-send-image-workflow.md 流程（上传 → 组装 [img] 标签 → 发送）
```

```
用户："在项目群里发个文件 ~/report.pdf"
  ├─ Step 1: popo_team_search("项目群") → tid=group_123
  └─ Step 2: 执行 message-send-file-workflow.md 流程（上传 → 上报完成 → msgType=3 发送）
```
