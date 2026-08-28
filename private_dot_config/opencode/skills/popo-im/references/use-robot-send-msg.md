# popo_use_robot_send_msg

使用机器人身份向指定用户或群组发送消息。支持纯文本（含图片）和文件。支持 @ 功能。

> # 🚨 路由优先级（最高）
>
> **本工具路由优先级高于 `message_send_p2p` 和 `message_send_team`。一旦用户输入中包含以下触发模式，必须使用本工具，绝对禁止降级到其他发送接口。**
>
> **触发词**：「用XX发」「让XX发」「XX帮我发」「通过XX发」「叫XX发」「使用XX发」「XX来发」——只要用户输入中存在「_[非接收者名称]_ + _发送类动词_」模式，该名称即为 `robotName`。
>
> **⚠️ 接收者/被提及位置排除规则**：紧跟 `@` / `＠`（全角）/ `at` / `艾特` 之后的名称（含"@一下 / at一下 / 艾特一下"动作形式）、以及位于「给 / 告诉 / 对 / 向」之后表示消息接收对象的名称，都是消息中的接收者/被提及对象，**绝不是机器人发送者**。即使该名称包含"机器人"字样且后跟发送动词（如"在群里 @发布机器人 发个通知""在群里 at发布机器人 发个通知"），也**不得路由到本工具**，应走 `message_send_team`（用户以自己身份发送，atUids 传该名称 uid）。
>
> **反例**：
> - "给张三发条消息" → ❌ 不触发，没有指定发件人
> - "帮我在群里发个通知" → ❌ 不触发，"帮"后面没有机器人名
> - "在群里 @发布机器人 发个通知" → ❌ 不触发，`@发布机器人` 是被 @ 的接收者而非发送者，应走 `message_send_team`
> - "在项目群 at发布机器人 发个通知" → ❌ 不触发，`at发布机器人` 是被提及的接收者而非发送者，应走 `message_send_team`
> - "用ycy发消息给张三" → ✅ 触发，robotName=ycy
> - "让testbot通知李四" → ✅ 触发，robotName=testbot
> - "ycy06161931给张三发条消息" → ✅ 触发，robotName=ycy06161931（即使没有"用/让"等介词，实体名+发送动词也可触发）

## 命令

> 🪟 **Windows 平台必读**：所有 `message` 参数（纯文本 / `[img]` / 文件 JSON）**强制走 `@text:` 临时文件**，不得在 shell 中直接传字符串。下方 macOS / Linux 示例**仅适用于 macOS / Linux**，Windows 一律参见后续 "Windows (PowerShell)" 段落。

### macOS / Linux

```bash
# 发送纯文本消息
popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=yinchunyuan@corp.netease.com message=123456 msgType=text

# 发送包含空格的消息（用引号包裹）
popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=yinchunyuan@corp.netease.com message="明天下午3点开会，请准时参加" msgType=text

# 发送图片消息（纯文本方式，[img] 标签包裹 FP 地址）
popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=yinchunyuan@corp.netease.com message="[img]http://fp.example.com/test.png[/img]" msgType=text

# 发送文件消息（msgType=file，message 为文件信息 JSON 字符串）
# ⚠️ message 值必须是 JSON 字符串，不能是 JSON 对象，否则服务端报错
# 跨平台（macOS / Linux / Windows）: 使用 =@text: 临时文件方式
# popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=yinchunyuan@corp.netease.com message=@text:$tmpFile msgType=file
# 详见 message-send-file-workflow.md 的 Step 5

# @所有人（receiver 为群组 tid 时）
popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=123456789 message="@所有人 注意了" msgType=text isAtAll=true

# @指定用户（macOS / Linux）
popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=123456789 message="这是一条消息 @张三 @李四" msgType=text isAtAll=false atUids="[\"zhangsan@corp.netease.com\",\"lisi@corp.netease.com\"]"
```

### Windows (PowerShell)

> ⚠️ **铁律**：`message` 参数（纯文本 / `[img]` / 文件 JSON）**必须**通过 UTF-8 无 BOM 临时文件 + `@text:` 传递；`atUids` 数组通过 `@file:` 临时文件传递。
>
> ⚠️ **GBK 编码陷阱**：PowerShell 5.1 读取不含 UTF-8 BOM 的 `.ps1` 文件时按系统 ANSI（GBK）解析源码，导致全角字符（`（）` `《》` `【】` `，。` 等）在脚本解析阶段损坏——`$msgContent` 拿到时已经是乱码。**`.ps1` 文件必须保存为 UTF-8 with BOM**。若写入工具无法直接指定 BOM，用以下方式创建：
> ```bash
> printf '\xEF\xBB\xBF' > script.ps1
> cat >> script.ps1 << 'PSEOF'
> ```
> 纯 ASCII 内容（如 `[img]` 标签、`@所有人`）不受此影响。

```powershell
# === 纯文本消息（P2P 给用户）===
$msgContent = "明天下午3点开会，请准时参加"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=yinchunyuan@corp.netease.com message="@text:$msgTmpFile" msgType=text
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}

# === 图片消息（[img] 标签）===
$msgContent = "[img]http://fp.example.com/test.png[/img]"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=yinchunyuan@corp.netease.com message="@text:$msgTmpFile" msgType=text
}
finally {
    Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
}

# === @所有人（receiver 为群组 tid）===
$msgContent = "@所有人 注意了"
$msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
try {
    [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
    popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=123456789 message="@text:$msgTmpFile" msgType=text isAtAll=true
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
    popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=123456789 message="@text:$msgTmpFile" msgType=text isAtAll=false atUids="@file:$atUidsTmpFile"
}
finally {
    Remove-Item -Path $msgTmpFile, $atUidsTmpFile -ErrorAction SilentlyContinue
}

# === 文件消息（msgType=file）===
# message JSON 的构造与写入流程详见 message-send-file-workflow.md 的 Step 5
# popo-cli popo use_robot_send_msg robotName=ycy06161931 receiver=yinchunyuan@corp.netease.com message="@text:$msgTmpFile" msgType=file
```

> **`try/finally` 是强制的**：保证 popo-cli 抛错 / 用户 Ctrl+C / `$ErrorActionPreference='Stop'` 任何场景下临时文件都会被清理。`Remove-Item -ErrorAction SilentlyContinue` 会忽略"文件不存在"错误，所以在第二个 `WriteAllText` 还没执行就异常时，传入未创建的路径也安全。

## 请求参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `robotName` | String | **是** | — | 机器人全名。⚠️ **必须使用用户精确说出的机器人全名，绝对不要走搜索流程**。直接作为参数传入即可 |
| `receiver` | String | **是** | — | 接收方。**用户 uid**（POPO 账号，格式为 `xxx@corp.netease.com`）或**群组 tid**（纯数字格式）。用户提供人名时通过 `popo_userinfo_search` 获取 uid；用户提供群名时通过 `popo_team_search` 获取 tid；用户直接提供 POPO 账号或群组 tid 时直接使用 |
| `message` | String | **是** | — | 消息内容。纯文本直接填写；图片用 `[img]FP地址[/img]` 包裹；文件填文件信息 JSON 字符串（详见 [message-send-file-workflow.md](message-send-file-workflow.md)） |
| `msgType` | String | **是** | `text` | 消息类型：`text`=纯文本（图片也用此类型，通过 `[img]` 标签表示），`file`=文件。**仅支持这两个值** |
| `isAtAll` | Boolean | 否 | `false` | 是否 @所有人。`true` 表示 @所有人（message 中需包含 `@所有人` 可见文本）。⚠️ **仅在 receiver 为群组 tid 时有效** |
| `atUids` | Array\<String\> | 否 | `[]` | 需要 @的用户 uid 列表。协议层真正用于 @ 提醒的字段，message 中的可见 @ 文本仅用于展示。⚠️ **仅在 receiver 为群组 tid 时有效** |

## 消息类型说明

| 类型 | msgType | message 内容 | 上传流程 | 支持 @ |
|------|---------|-------------|---------|:------:|
| **纯文本** | `text`（默认） | 文本内容 | 无需上传 | ✅ |
| **图片** | `text`（默认） | `[img]FP地址[/img]` | 读取 [message-send-image-workflow.md](message-send-image-workflow.md) | ✅ |
| **文件** | `file` | 文件信息 JSON 字符串 | 读取 [message-send-file-workflow.md](message-send-file-workflow.md) | ❌ |

> ⚠️ **图片不是独立的消息类型，以 msgType=text 发送 `[img]` 标签实现。** 这与 `message_send_p2p` 和 `message_send_team` 的图片发送方式一致。

## receiver 路由规则

| receiver 格式 | 含义 | 解析方式 |
|---------------|------|---------|
| `xxx@corp.netease.com` | 用户 POPO 账号（uid） | 直接使用，无需搜索 |
| 中文姓名（如"张三"） | 用户姓名 | 通过 `popo_userinfo_search` 获取 uid |
| 纯数字（如 `123456789`） | 群组 tid | 直接使用，无需搜索 |
| 群名（如"项目讨论群"） | 群组名称 | 通过 `popo_team_search` 获取 tid |

## @ 功能说明

> ⚠️ **@ 功能仅在 receiver 为群组 tid（纯数字格式）时有效。** receiver 为用户 uid（邮箱格式）时，`atUids` 和 `isAtAll` 参数无效，不能使用 @ 功能（与 `message_send_p2p` 一致）。
>
> ⚠️ **仅 msgType=text 支持 @ 功能，msgType=file 不支持。**

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

与群消息 @ 功能规则一致（详见 [message-send-team.md](message-send-team.md) § @ 功能说明）：

> ⚠️ **禁止在 message 中写 `@邮箱`**（如 `@zhangsan@corp.netease.com`），这种写法不会被解析，对方收不到 @ 提醒。
>
> ⚠️ **禁止自动邀请不在群内的用户入群**。@ 某人时，如果该用户不在群内，应告知用户该成员不在群中，由用户自行决定是否邀请入群，**不得自行调用 `popo_team_invite` 拉人**。

## 使用要点

### 发送流程

1. **确定机器人名称**：⚠️ **直接使用用户精确说出的机器人全名作为 `robotName` 参数，绝对不要走 `popo_userinfo_search` 搜索流程**。机器人名是原样传递的，不做任何转换或查询
2. **解析接收方**：
   - 用户直接提供 `xxx@corp.netease.com` 格式的 POPO 账号 → **直接用作 receiver**，无需搜索
   - 用户直接提供纯数字 tid → **直接用作 receiver**（群组），无需搜索
   - 用户提到人名（如"张三"）→ 通过 `popo_userinfo_search` 获取 uid，**不要猜测**
   - 用户提到群名（如"项目讨论群"）→ 通过 `popo_team_search` 获取 tid，**不要猜测群 ID**
3. **判断消息类型**：
   - 纯文本 → 直接调用发送（`msgType=text`）
   - 图片 → 读取 [message-send-image-workflow.md](message-send-image-workflow.md) 执行上传流程，然后用 `[img]` 标签 + `msgType=text` 发送
   - 文件 → 读取 [message-send-file-workflow.md](message-send-file-workflow.md) 执行上传流程（`msgType=file`）
4. **判断是否需要 @**（仅 receiver 为群组 tid 且 msgType 为 text 时）：
   - ⚠️ **receiver 为用户 uid（邮箱格式）时，不支持 @ 功能**，直接跳过此步骤
   - 用户要求 @所有人 → 设置 `isAtAll=true`，message 中加入 `@所有人`
   - 用户要求 @某人 → 通过 `popo_userinfo_search` 查询，将 `content.uid` 放入 `atUids`，**从返回结果中优先取 `content.showName`（为空则取 `content.name`）**（不得直接使用用户输入的名字）拼接为 `@显示名` 写入 message
   - 用户直接提供了 POPO 账号但需要 @ → 账号放入 `atUids`，**仍需查询 `popo_userinfo_search` 获取 `content.showName`（或 `content.name`）写入 message**（禁止 `@邮箱`）
   - @所有人 与 @指定用户可同时使用
5. **调用发送**：使用机器人名、接收方 uid/tid 和消息内容调用 `popo_use_robot_send_msg`
6. **结果反馈**：告知用户机器人消息已发送

### 典型场景

```
用户："用 ycy06161931 机器人给张三发条消息，说明天下午开会"
  ├─ Step 1: 机器人名 ycy06161931（直接使用，不搜索）
  ├─ Step 2: popo_userinfo_search("张三") → zhangsan@corp.netease.com
   └─ Step 3: popo_use_robot_send_msg(robotName="ycy06161931", receiver="zhangsan@corp.netease.com", message="明天下午开会", msgType=text)
```

```
用户："用 ycy06161931 机器人在项目讨论群里发条消息，说明天开会"
  ├─ Step 1: 机器人名 ycy06161931（直接使用，不搜索）
  ├─ Step 2: popo_team_search("项目讨论群") → tid=123456789
  └─ Step 3: popo_use_robot_send_msg(robotName="ycy06161931", receiver="123456789", message="明天开会", msgType=text)
```

```
用户："用 ycy06161931 机器人给 yinchunyuan@corp.netease.com 发条消息，说你好"
  ├─ 机器人名 ycy06161931（直接使用，不搜索）
  └─ Step 1: popo_use_robot_send_msg(robotName="ycy06161931", receiver="yinchunyuan@corp.netease.com", message="你好", msgType=text)
  （用户直接提供了 POPO 账号，无需 popo_userinfo_search）
```

```
用户："用 ycy06161931 机器人给张三发一张图片 ~/screenshot.png"
  ├─ Step 1: 机器人名 ycy06161931（直接使用，不搜索）
  ├─ Step 2: popo_userinfo_search("张三") → zhangsan@corp.netease.com
  └─ Step 3: 执行 message-send-image-workflow.md 流程（上传 → 组装 [img] 标签 → 以 msgType=text（默认）发送）
```

```
用户："用 ycy06161931 机器人给张三发个文件 ~/report.pdf"
  ├─ Step 1: 机器人名 ycy06161931（直接使用，不搜索）
  ├─ Step 2: popo_userinfo_search("张三") → zhangsan@corp.netease.com
  └─ Step 3: 执行 message-send-file-workflow.md 流程（上传 → 上报完成 → msgType=file 发送）
```

```
用户："用 ycy06161931 机器人在项目群里 @所有人 再 @张三 说注意查收"
  ├─ Step 1: 机器人名 ycy06161931（直接使用，不搜索）
  ├─ Step 2: popo_team_search("项目群") → tid=123456789
  ├─ Step 3: popo_userinfo_search("张三") → uid=zhangsan@corp.netease.com, showName=张三
  └─ Step 4: popo_use_robot_send_msg(robotName="ycy06161931", receiver="123456789", message="@所有人 @张三 注意查收", msgType=text, isAtAll=true, atUids=["zhangsan@corp.netease.com"])
```

## 与其他消息接口的区别

| 特性 | `message_send_p2p` | `message_send_team` | `message_send_filehelper` | `use_robot_send_msg` |
|------|:---:|:---:|:---:|:---:|
| 发送者身份 | 当前用户 | 当前用户 | 当前用户 | 指定机器人 |
| 需要指定发送者 | ❌ | ❌ | ❌ | ✅（`robotName`） |
| receiver 格式 | 用户 uid（邮箱格式） | 群组 tid（纯数字） | 无需 | 用户 uid 或群组 tid |
| receiver 搜索 | 人名 → `userinfo_search` | 群名 → `team_search` | 无需 | 人名 → `userinfo_search`；群名 → `team_search` |
| msgType | Integer（1/3） | Integer（1/3） | Integer（1/3） | String（text/file） |
| 图片发送方式 | `[img]` 标签 + msgType=1 | `[img]` 标签 + msgType=1 | `[img]` 标签 + msgType=1 | `[img]` 标签 + msgType=text（默认） |
| source 参数 | `AGENT` | `AGENT` | `AGENT` | **无需** |
| 支持 @ | ❌（P2P 无 @） | ✅ | ❌ | ✅（仅 receiver 为群组 tid 时） |
