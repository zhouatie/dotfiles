---
name: popo-im
description: "POPO IM 消息与群组管理：搜索聊天消息、发送消息（文本/图片/文件）、使用机器人发消息、发送消息给文件传输助手（发给自己）、搜索员工/用户信息、搜索群组、创建群聊、管理群成员、修改群名、查询群详情（公告/成员列表）。触发场景：(1) 消息搜索 —\"帮我找关于X的消息\"、\"张三说过什么关于Y的内容\"、\"在某某群里搜索Z\"、\"最近关于项目进度的讨论\"，以及任何涉及搜索/查找/回顾POPO聊天记录、IM消息、群聊内容的请求；(2) 发送消息 —\"帮我给张三发条消息\"、\"在项目群里发个通知\"、\"告诉李四明天开会\"、\"给XX群发消息说YY\"、\"帮我给张三发张图片\"、\"在群里发个截图\"、\"帮我给李四发个文件\"、\"在群里发个附件\"、\"发给文件传输助手\"、\"发给自己一条备忘\"，以及任何涉及通过POPO发送/传达消息、图片、文件的请求；(2b) 机器人发消息 —\"用ycy给张三发条消息\"、\"让testbot通知李四明天开会\"、\"ycy06161931给张三发条消息\"、\"用XX机器人给张三发张图片\"、\"用XX机器人给张三发个文件\"，以及任何涉及「用/让/通过/叫 + 非接收者名称 + 发送类动词」模式的请求。不需要出现\"机器人\"三个字，只要有「指定发送者身份」的意图就触发；(3) 用户查询 —\"张三的邮箱是什么\"、\"帮我查下李四的部门\"、\"搜索叫王五的同事\"、查看个人信息、查找联系方式、按姓名搜索员工；(4) 群组搜索 —\"帮我找项目讨论群\"、\"搜索XXX相关的群\"；(5) 群组管理 —\"帮我创建一个群\"、\"把张三拉到XX群\"、\"把李四从XX群移除\"、\"把XX群改名为YY\"；(6) 群详情查询 —\"看看群里都有谁\"、\"按部门分组列一下群成员\"、\"查一下群公告写了什么\"、\"这个群有哪些人\"；(7) 消息表情回应 —\"用XX机器人给那条消息点个赞\"、\"给这条消息回应个爱心\"、\"把机器人回应的表情取消掉\"，即对已有消息添加/取消系统表情回应（reaction）。即使用户没有明确说\"搜索\"或\"发送\"，只要意图涉及查找POPO中的消息、人员、群组，发送POPO消息（文本、图片、文件），使用机器人发送消息，发送消息给文件传输助手/自己，管理群组（创建、成员变更、改名），查询群详情（公告/成员），或对已有消息做表情回应，都应使用此skill。"
---

# POPO IM 消息与群组管理

所有操作通过 Bash 执行 `popo-cli <工具名> key=value` 命令完成。

> **参数值引号规则（跨平台兼容，禁止使用单引号）**
>
> 为确保命令在 bash、CMD、PowerShell 等不同 shell 下均能正确执行，统一使用**双引号**作为引用符：
> - 简单值（无空格、无特殊字符）**不加引号**：`key=value`
> - 含空格或特殊字符的值用**双引号**包裹：`key="value with spaces"`
> - **macOS / Linux**：JSON 数组/对象用**双引号**包裹，内部双引号使用 `\"` 转义：`key="[\"a\",\"b\"]"`
> - **Windows**：`\"` 转义在 PowerShell 中不可靠，JSON 数组/对象参数须写入临时文件后用 `=@file:` 传递（`@file:` 会将文件内容解析为 JSON 值而非字符串，详见各命令参考文档中的 Windows 示例）
> - 单个数组值也使用数组格式：`uidList="[\"zhangsan@example.com\"]"`（macOS/Linux）/ `=@file:` 临时文件（Windows）
> - **Windows 下所有发送消息接口的 `message` 参数**（无论纯文本、`[img]` 还是文件 JSON）**强制走 `@text:` 临时文件**，详见下方"Windows 铁律 — 所有 `message` 参数必须走 `@text:` 临时文件"小节
>
> ```bash
> # ✅ 简单值 — 不需要引号
> popo-cli popo userinfo_search query=张三 type=2 page=0 pageSize=10 searchRange=1 includeRobot=true
>
> # ✅ 含空格 — 双引号包裹
> popo-cli popo team_create uid=liuyawei@corp.netease.com name="哈哈哈 V1" type=1
>
> # ✅ 数组参数 — 双引号包裹 + 内部 \" 转义
> popo-cli popo team_create type=1 uidList="[\"zhangsan@example.com\",\"lisi@example.com\"]"
>
> # ✅ 复杂嵌套对象同理
> popo-cli popo message_context sessionMsg="[{\"sessionId\":\"s1\",\"sessionType\":1,\"uuids\":[\"msg_001\"],\"msgTime\":1709000000000}]"
>
> # ❌ 错误 — 空格导致参数断裂
> popo-cli popo team_create name=哈哈哈 V1
>
> # ❌ 错误 — 使用单引号（Windows CMD 不支持）
> popo-cli popo team_create uidList='["zhangsan@example.com"]'
> ```

> ⚠️ **`\"` 转义仅用于命令行直传参数，不用于临时文件内容**
>
> 上述 `\"` 转义规则适用于在命令行中直接传递 JSON 参数的场景。当使用 `=@text:` 临时文件方式传参时（如文件发送流程），写入临时文件的内容必须是**原始合法 JSON**，不需要任何反斜杠转义。
>
> ```powershell
> # ✅ 正确 — 用对象 + ConvertTo-Json 序列化，再写入 UTF-8 无 BOM 文件
> $obj = @{ fileID = $id; name = $name }
> $json = $obj | ConvertTo-Json -Compress
> [System.IO.File]::WriteAllText($tmpFile, $json, [System.Text.UTF8Encoding]::new($false))
> popo-cli popo message_send_p2p message="@text:$tmpFile" source="AGENT" ...
>
> # ❌ 错误 — 临时文件内容不需要 \" 转义
> $json = '{\"fileID\":\"' + $id + '\",\"name\":\"' + $name + '\"}'
> ```

> 🚫 **绝对禁止：在 Windows 平台手工拼接 JSON 字符串**
>
> 任何需要构造 JSON 的场景（包括但不限于文件消息的 `message` 参数），都必须遵守以下铁律：
>
> 1. 先构造 PowerShell 对象（哈希表 `@{...}` 或 PSCustomObject）
> 2. 使用 `ConvertTo-Json -Compress` 序列化为字符串
> 3. 使用 `[System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))` 写入 UTF-8 **无 BOM** 文件
> 4. 通过 `message="@text:$path"`（**路径必须用双引号包裹**）传递给 popo-cli
>
> **禁止行为**：
> - ❌ 手工字符串拼接 JSON（`'{"key":"' + $val + '"}'`）—— 一旦值含 `"`、`\`、换行，JSON 立刻损坏
> - ❌ 在 shell 中转义 JSON（`"{\"key\":\"value\"}"`）—— Windows quoting 不可靠
> - ❌ 使用 `Set-Content -Encoding UTF8`（PS 5.1 写 BOM）或 `Out-File`（默认 UTF-16）
> - ❌ 使用 CMD 执行复杂 JSON 参数（CMD 没有现代 quoting 能力）
> - ❌ 用 `powershell -Command "..."` 包裹再传 JSON（引号语义会被二次解析）
>
> `ConvertTo-Json` 把中文转义为 `\uXXXX` 是 **JSON 标准合法行为**，服务端会等价解析，**不是问题**。真正的问题是 BOM、shell quoting、非 UTF-8 与非法 JSON。

> 🪟 **Windows 铁律 — 所有 `message` 参数必须走 `@text:` 临时文件**
>
> Windows 平台（PowerShell / Git Bash / Cmder 等）下，**任何**发送消息接口（`message_send_p2p` / `message_send_team` / `message_send_filehelper` / `use_robot_send_msg`）的 `message` 参数，**无论消息内容是什么类型**，都必须通过 UTF-8 无 BOM 临时文件 + `@text:` 方式传递，**禁止**直接通过 shell 引号传字符串。
>
> **适用范围（无例外）**：
>
> | 消息类型 | 传参方式 | 说明 |
> |---------|---------|------|
> | 纯文本（含空格 / 中文 / `&` / `(` / `)` / 换行） | `message="@text:$tmpFile"` | shell quoting 不可靠，必须走临时文件 |
> | `[img]url[/img]` 图片消息 | `message="@text:$tmpFile"` | URL 含 `&`、`?` 会被 shell 解析，必须走临时文件 |
> | 文件消息 JSON（`msgType=3` / `file`） | `message="@text:$tmpFile"` | 已有约定，保持不变 |
>
> **标准四步流程（所有消息类型通用，必须用 `try/finally` 保证清理）**：
>
> ```powershell
> # 1. 准备消息内容（PowerShell 原生字符串，不参与任何 shell 转义）
> $msgContent = "明天下午3点开会，请准时参加"   # 或 "[img]http://fp.../xxx[/img]"，或 file JSON
>
> # 2. 创建 GUID 唯一名临时文件路径（防并发冲突）
> $msgTmpFile = Join-Path $env:TEMP "popo_msg_$([guid]::NewGuid().ToString('N')).txt"
>
> # 3. try/finally 保证无论成功、失败、Ctrl+C 都清理临时文件
> try {
>     # 3a. 写入 UTF-8 无 BOM（务必用 WriteAllText，禁止 Set-Content / Out-File）
>     [System.IO.File]::WriteAllText($msgTmpFile, $msgContent, [System.Text.UTF8Encoding]::new($false))
>
>     # 3b. 通过 @text: 传文件路径（路径必须用双引号包裹）
>     popo-cli popo message_send_p2p message="@text:$msgTmpFile" receiver=zhangsan@example.com source=AGENT
> }
> finally {
>     # 4. 无条件清理（即使 popo-cli 抛错 / 用户 Ctrl+C / 上层 $ErrorActionPreference='Stop' 都会执行）
>     Remove-Item -Path $msgTmpFile -ErrorAction SilentlyContinue
> }
> ```
>
> ⚠️ **`try/finally` 是强制的，不是可选**：PowerShell 默认遇到 native 命令非零退出不抛异常，但**用户 Ctrl+C、上层 `$ErrorActionPreference='Stop'`、终止性异常**都会跳过后续语句，直接泄漏文件到 `$env:TEMP`。`finally` 块在任何情况下（包括 `return` / `throw` / `Ctrl+C`）都会执行。
>
> **为什么必须强制（即使内容看起来"很安全"）**：
> - PowerShell / CMD / Git Bash 的引号语义**互不兼容**，无法在调用前预判使用了哪个 shell
> - 中文在 PS 5.1 控制台默认 GBK，shell 字面量传递时会在 popo-cli 进程读取前已损坏
> - 空格、`&`、`(`、`)`、`|`、`<`、`>`、`"` 等字符在不同 shell 下被切分/重定向/求值的规则**完全不同**
> - 临时文件路径**仅含 ASCII 与数字**（`$env:TEMP` 标准路径），shell 不会出错
> - 临时文件以**字节流**形式传递内容，**完全绕开** shell 解析层 —— 这是 Windows 跨终端唯一稳定方案
>
> **禁止行为**：
> - ❌ `message="明天开会"` —— 含中文/空格在 PS 5.1 GBK 终端必乱码
> - ❌ `message="[img]$url[/img]"` —— URL 含 `&` 会被 shell 截断
> - ❌ `message=$content` —— 不带双引号包裹，路径含空格直接炸
> - ❌ 用 `echo $msg > $tmpFile` / `Set-Content` / `Out-File` 写文件 —— 编码或 BOM 不对
>
> > ⚠️ **`.ps1` 文件 UTF-8 BOM**：即使使用 `@text:` 绕过 shell 编码问题，`.ps1` 脚本本身若不含 BOM，PS 5.1 仍会按 GBK 解析源码，全角字符（`（）` 等）在 `$msgContent` 赋值前已损坏。创建 `.ps1` 时用 `printf '\xEF\xBB\xBF' > script.ps1` 写入 BOM 头。
>
> **macOS / Linux 不受此约束**：原生 UTF-8 + 单一 shell 语义清晰，`message="..."` 双引号传递即可，无需多一层临时文件。

> **兜底：HTTP 直传调用**
> 当 `popo-cli <工具名> key=value` 调用后服务端返回类型解析错误（如 `Cannot construct instance of java.util.ArrayList`、`JSON parse error` 等），说明参数中的数组/对象值未被正确序列化。此时改用 HTTP 直传方式重试，手动构造合法 JSON 以保证类型正确：
> ```
> popo-cli call POST /api/v1/open-apis/gateway/appcode/popo/_invoke --body "{\"tool\":\"<工具名>\",\"params\":{...}}"
> ```
> 示例：
> ```bash
> popo-cli call POST /api/v1/open-apis/gateway/appcode/popo/_invoke --body "{\"tool\":\"popo_message_search\",\"params\":{\"query\":\"进度\",\"sessionList\":[\"session1\",\"session2\"]}}"
> ```

## 查询类型路由

> # 🚨 路由优先级（必须最先判断）
>
> **在处理任何发送消息请求之前，必须首先检查用户是否指定了机器人身份。**
>
> **机器人触发词**：「用XX发」「让XX发」「XX帮我发」「通过XX发」「叫XX发」「使用XX发」「XX来发」等——只要用户输入中包含「_[实体名]_ + 发/发送/通知/告诉」模式，且该实体名**不是已知的接收者人名**、**且不处于接收者/被提及位置**，就触发机器人发消息路由。
>
> **⚠️ 核心判定原则：只有当名称被明确置于"发件人"位置时，它才是机器人发送者；凡名称处于"接收者/被提及"位置，绝不是发送者。** 判定依据是名称的**语义角色**，而非某个固定标记词。
>
> **"接收者/被提及"位置（该位置的名称一律不是发送者）**，包括但不限于：
> - 紧跟 `@` / `＠`（全角）/ `at` / `艾特` 之后的名称（含"@一下 / at一下 / 艾特一下"动作形式），如 `@发布机器人`、`at发布机器人`、`艾特发布机器人`、`＠张三`
> - 位于「给 / 告诉 / 对 / 向」之后、表示消息接收对象的名称，如"给张三发消息"
>
> 即使该名称包含"机器人"字样、且后面也跟了发送动词（如"在群里 @发布机器人 发个通知""在群里 at发布机器人 发个通知"），只要它处于接收者/被提及位置，就必须走 `message_send_team`（用户以自己身份发送，并在 atUids 中 @ 该名称），**严禁路由到 `use_robot_send_msg`**。接收者位置标志的优先级高于「实体名 + 发送动词」模式。
>
> **兜底**：名称的语义角色无法明确判断时（既无明显发件人标志、也无接收者/被提及标志），默认按用户自己身份发送（`message_send_team`，必要时在群消息中 @ 该名称），不擅自使用机器人身份；仅当两种解读都会造成明显错误的发送行为时才追问确认。
>
> **判断逻辑**：
> 1. 提取用户输入中「用/让/通过/叫/使用」后面的名称 → 候选机器人名
> 2. **先剔除接收者/被提及位置上的名称**：紧跟 `@`/`＠`/`at`/`艾特` 之后、或位于「给/告诉/对/向」之后表示接收对象的名称，都是接收者/被提及对象，直接排除出候选机器人名（该对象仍可作为 `message_send_team` 的 atUids 成员）
> 3. 如果该名称同时出现在接收者位置（如"用张三发消息给张三"），用户意图模糊，**追问确认**
> 4. 如果该名称**不在接收者位置**，它就是机器人名 → **强制使用 `use_robot_send_msg`**，绝对不允许降级为 `message_send_p2p` 或 `message_send_team`
>
> **典型误判场景（必须避免）**：
> | 用户输入 | ❌ 错误路由 | ✅ 正确路由 |
> |----------|------------|------------|
> | "用ycy发消息给张三" | `message_send_p2p` → 以当前用户身份发 | `use_robot_send_msg` → 以 ycy 机器人身份发 |
> | "让testbot通知李四明天开会" | `message_send_p2p` → 以当前用户身份发 | `use_robot_send_msg` → 以 testbot 机器人身份发 |
> | "机器人ycy06161931给张三发条消息" | `message_send_p2p` → 以当前用户身份发 | `use_robot_send_msg` → 以 ycy06161931 机器人身份发 |
> | "在群里 @发布机器人 发个通知" | `use_robot_send_msg` → 误以为以发布机器人身份发 | `message_send_team` → 用户自己发，@发布机器人（atUids 传机器人 uid） |
> | "在项目群 at发布机器人 发个通知" | `use_robot_send_msg` → 误以为以发布机器人身份发 | `message_send_team` → 用户自己发，@发布机器人（atUids 传机器人 uid） |
> | "帮我在项目群里发个通知" | `message_send_team` → 以当前用户身份发 | `message_send_team` → 没有指定机器人，正确 ✅ |
> | "给张三发条消息" | 任何机器人路由 | `message_send_p2p` → 没有指定机器人，正确 ✅ |
>
> ⚠️ **一旦识别到机器人触发词且排除接收者歧义，就锁定 `use_robot_send_msg` 路由，不再根据 receiver 格式做二次路由判断。** receiver 是 uid 还是 tid 只影响 `use_robot_send_msg` 内部的解析流程，不能改变路由决策。

收到用户请求后，先判断查询类型，再进入对应流程：

| 查询类型 | 典型意图 | 流程 |
|----------|---------|------|
| **消息搜索** | 查找聊天记录、搜索某人说过的话、回顾讨论历史 | 读取 [workflow.md](references/workflow.md) 执行完整流程 |
| **用户查询** | 查找同事邮箱/部门/联系方式、按姓名搜索员工 | 读取 [userinfo-search.md](references/userinfo-search.md)，直接回复 |
| **群组搜索** | 查找群聊、搜索群名 | 读取 [team-search.md](references/team-search.md)，直接回复 |
| **创建群组** | 创建群聊、建群拉人 | 先调用 `popo-cli popo team_current_user_info` 获取当前用户 uid，再读取 [team-create.md](references/team-create.md)，执行创建流程 |
| **邀请群成员** | 把某人拉到群里、添加群成员 | 读取 [team-invite.md](references/team-invite.md)，执行邀请流程 |
| **移除群成员** | 把某人从群里移除/踢出 | 读取 [team-kick-member.md](references/team-kick-member.md)，执行移除流程 |
| **修改群名** | 改群名、重命名群 | 读取 [team-update-name.md](references/team-update-name.md)，执行修改流程 |
| **群详情查询** | 查看群公告、查看群成员列表 | 读取 [team-info-query.md](references/team-info-query.md)，直接回复 |
| **发送单聊消息** | 给某人发消息、私聊发通知 | 读取 [message-send-p2p.md](references/message-send-p2p.md)，执行发送流程 |
| **发送群消息** | 在群里发消息、群发通知、@人、@所有人 | 读取 [message-send-team.md](references/message-send-team.md)，执行发送流程 |
| **发送消息给文件传输助手** | 发给文件传输助手、发给自己、备忘消息 | 读取 [message-send-filehelper.md](references/message-send-filehelper.md)，执行发送流程（无需查询用户） |
| **机器人发消息** | **「用XX发」「让XX发」「XX帮我发」「通过XX发」「叫XX发」「使用XX发」「XX来发」+ 接收者**。任何「实体名 + 发/发送/通知/告诉」模式，且该实体名不是已知接收者时触发 | 读取 [use-robot-send-msg.md](references/use-robot-send-msg.md)，执行发送流程（机器人名直接使用不搜索，receiver 按需搜索）。**路由优先级最高，一旦命中不得降级为 P2P/群消息** |
| **消息表情回应** | **对已存在的某条消息添加/取消系统表情回应**（reaction）。"给那条消息点个赞""用XX机器人给这条消息回应个爱心""把机器人回应的表情取消掉" | 读取 [sticker-quick-reply.md](references/sticker-quick-reply.md)，执行添加/取消表情回应流程。目标消息（`msgId`/`sessionId`）来自 `popo_message_search`，中文表情名→枚举名映射见 [sticker-enum.md](references/sticker-enum.md) |

> **发送消息时 P2P / 群消息 / 文件传输助手路由规则（必须严格遵守）**
>
> 根据用户意图和 receiver 的**格式**判断走哪条链路：
>
> | 场景 | 消息类型 | 使用接口 | 说明 |
> |------|---------|---------|------|
> | 用户提到"文件传输助手"或"发给自己" | **文件传输助手** | `message_send_filehelper` | 无需 receiver 参数，无需查询用户 |
> | receiver 为邮箱格式（包含 `@`，如 `xxx@corp.netease.com`） | **P2P 单聊** | `message_send_p2p` | 所有邮箱格式账号都是个人账号，包括 `grp.xxx@corp.netease.com` 这类特殊账号 |
> | receiver 为纯数字（如 `123456789`） | **群消息** | `message_send_team` | 纯数字是群组 tid，需通过 `popo_team_search` 获取 |
>
> ⚠️ **`grp.` 开头的邮箱地址不是群组！** 它是个人特殊账号，必须走 P2P 单聊链路。只有纯数字的 tid 才代表群组。
>
> ⚠️ **以上路由规则仅在用户没有指定机器人身份时适用。** 如果用户输入包含机器人触发词（「用XX发」「让XX发」等），跳过此路由表，直接走 `use_robot_send_msg`。详见上方「路由优先级」。
| **发送图片消息** | 给某人/群发图片、照片、截图 | 读取 [message-send-image-workflow.md](references/message-send-image-workflow.md)，执行上传+发送流程 |
| **发送文件消息** | 给某人/群发文件、文档、附件 | 读取 [message-send-file-workflow.md](references/message-send-file-workflow.md)，执行上传+发送流程 |

> 所有查询结果和操作结果均按格式直接在对话中回复。

## NEVER DO

- **创建群组时，不要将当前用户 uid 放入 `uidList`**。`uid` 参数（当前用户）自动入群，`uidList` 只放其他人。用户说"把我也拉进去"、"我也要在群里"时，无需额外处理——创建者本身就在群里
- 不要手动构造 `session_id` / `tid` 等 ID 类参数值，必须从接口查询获取
- 不要猜测或编造用户 uid，必须通过 `popo_userinfo_search` 搜索获取。但如果用户**直接提供了 `xxx@corp.netease.com` 或 `xxx@mesg.corp.netease.com` 格式的 POPO 账号**，则直接使用，无需搜索
- **`msgType` 只允许两个值：`1`（纯文本/图片）和 `3`（文件）。绝对不要传 `msgType=0` 或其他值。** 发送纯文本或图片消息时，直接省略 `msgType` 参数（服务端默认为 1），不要显式传任何值
- 不要猜测或编造群 ID，必须通过 `popo_team_search` 搜索获取
- **机器人发消息时，`robotName` 必须使用用户精确说出的机器人全名，绝对不要走 `popo_userinfo_search` 搜索流程**。即使搜索结果中有看起来匹配的机器人名，也必须原样使用用户输入的名称，不得做任何转换、查询或校验
- **只要用户指定了机器人身份（「用XX发」「让XX发」「XX帮我发」等），必须走 `use_robot_send_msg`，绝对禁止回退到 `message_send_p2p` 或 `message_send_team`**。即使请求看起来像普通发消息，机器人路由优先级最高，不得因为"接收者是邮箱格式"就改用 P2P 接口
- 不要使用 curl 或自己写 python 等方法直接调用 POPO API（**文件上传除外**：上传文件到 FP/S3 地址时使用 curl；**Windows 平台必须使用 `curl.exe`** 而非 `curl`，因为 PowerShell 中 `curl` 是 `Invoke-WebRequest` 的别名）
- 所有时间参数使用**毫秒级 Unix 时间戳**（如 `1709000000000`），不要传 ISO-8601 格式
- 实体搜索（群名/人名）命中数量大于 3 个时，**取 top 3**（结果列表前 3 个）
- 执行**破坏性群操作**（移除成员、修改群名）前，必须**先与用户确认**再执行
- 群组管理操作失败时，不要自行重试或尝试替代方案，将错误信息报告给用户
- **群消息 @ 人时，`message` 中 `@` 后面必须使用 `popo_userinfo_search` 返回的 `content.name` 字段值，禁止直接使用用户输入的名字，禁止跟邮箱**。即使用户说的名字看起来和搜索结果一致，也必须从接口返回的 `content.name` 中提取，不得跳过取值步骤直接复用用户输入。`@邮箱` 不会被客户端解析，对方收不到 @ 提醒
- **群消息 @ 人时，禁止自动邀请不在群内的用户入群**。如果被 @ 的人不在群里，应告知用户该成员不在群中，由用户决定是否邀请，不得自行调用 `popo_team_invite`

## 能力总览

| 操作 | 命令 | 独立使用 | 说明 | 参考 |
|------|------|:--------:|------|------|
| 消息搜索 | `popo-cli popo message_search` | — | 根据关键词和筛选条件搜索聊天消息 | [message-search.md](references/message-search.md) |
| 消息上下文 | `popo-cli popo message_context` | — | 根据消息 ID 查询前后上下文消息 | [message-context.md](references/message-context.md) |
| 搜索用户 | `popo-cli popo userinfo_search` | ✅ | 按姓名/昵称搜索员工，查看组织架构 | [userinfo-search.md](references/userinfo-search.md) |
| 获取当前用户 | `popo-cli popo team_current_user_info` | ✅ | 获取当前登录用户信息（uid 等），创建群组前必须调用 | — |
| 搜索群组 | `popo-cli popo team_search` | ✅ | 按群名关键词搜索群组 | [team-search.md](references/team-search.md) |
| 创建群组 | `popo-cli popo team_create` | ✅ | 创建新群组并拉入成员（需先获取当前用户 uid） | [team-create.md](references/team-create.md) |
| 邀请群成员 | `popo-cli popo team_invite` | ✅ | 邀请新成员加入已有群组 | [team-invite.md](references/team-invite.md) |
| 移除群成员 | `popo-cli popo team_kick_member` | ✅ | 从群组中移除成员 | [team-kick-member.md](references/team-kick-member.md) |
| 修改群名 | `popo-cli popo team_update_team_name` | ✅ | 修改群组名称 | [team-update-name.md](references/team-update-name.md) |
| 查询群详情 | `popo-cli popo team_info_query` | ✅ | 查询群公告内容或群成员列表（姓名、邮箱、组织） | [team-info-query.md](references/team-info-query.md) |
| 发送单聊消息 | `popo-cli popo message_send_p2p` | ✅ | 向指定用户发送单聊消息（支持文本、图片、文件） | [message-send-p2p.md](references/message-send-p2p.md) |
| 发送群消息 | `popo-cli popo message_send_team` | ✅ | 向指定群组发送消息（支持文本、图片、文件、@人、@所有人） | [message-send-team.md](references/message-send-team.md) |
| 发送消息给文件传输助手 | `popo-cli popo message_send_filehelper` | ✅ | 向文件传输助手发送消息，即发给自己（支持文本、图片、文件），无需 receiver | [message-send-filehelper.md](references/message-send-filehelper.md) |
| 机器人发消息 | `popo-cli popo use_robot_send_msg` | ✅ | 以指定机器人身份发送消息（支持文本、图片、文件、@人、@所有人）。⚠️ 机器人名直接使用不搜索，receiver 按需搜索 | [use-robot-send-msg.md](references/use-robot-send-msg.md) |
| 消息表情回应 | `popo-cli popo message_sticker_quick_reply` | — | 以机器人身份对已有消息添加/取消系统表情回应（reaction）。msgId/sessionId 来自消息搜索 | [sticker-quick-reply.md](references/sticker-quick-reply.md) / [sticker-enum.md](references/sticker-enum.md) |
| 获取图片上传地址 | `popo-cli popo message_fp_upload_url` | — | 获取 FP 上传地址，用于图片上传 | [message-send-image-workflow.md](references/message-send-image-workflow.md) |
| 获取文件上传地址 | `popo-cli popo message_s3_ufile_upload` | — | 获取 S3 上传地址，用于文件上传 | [message-send-file-workflow.md](references/message-send-file-workflow.md) |
| 上报文件上传完成 | `popo-cli popo message_s3_ufile_upload_complete` | — | 文件上传 S3 后上报，换取 ufid 和 ftype | [message-send-file-workflow.md](references/message-send-file-workflow.md) |
| 响应数据裁剪 | `jq` 管道 | — | 过滤消息搜索冗余字段（内联 jq 命令，无外部脚本依赖） | — |

## 消息搜索权限边界

**POPO 消息搜索 API 只能返回当前登录用户自己参与的消息。**（此规则仅限消息搜索，不影响用户/群组查询和群组管理操作）

| 查询意图 | 可搜索 | 原因 |
|----------|--------|------|
| 我和张三聊过的关于 XX 的消息 | ✅ | 当前用户参与 |
| 张三在 XX 群里说过什么关于 Y | ✅ | 当前用户也在群里 |
| 我最近关于进度的所有消息 | ✅ | 全局搜索，用户参与 |
| 张三和李四之间关于 XX 的消息 | ❌ | 当前用户未参与 |

判断为无效查询时，直接回复：

```
抱歉，POPO 消息搜索只能查询您自己参与的对话（您发送或接收的消息）。
查询 [张三] 和 [李四] 之间的消息超出了可访问范围。

如果您想搜索：
- 您和张三的对话 → 可以帮您搜索
- 张三在某个您也在的群里说过的内容 → 可以帮您搜索
```

## 群组管理通用流程

群组管理操作（创建、邀请、移除、改名）共享以下通用模式：

### 实体解析

所有群操作都可能需要预先解析实体：

| 用户提到 | 需要解析 | 使用工具 | 提取字段 |
|----------|---------|---------|----------|
| 群名 | 群 ID（tid） | `popo_team_search` | `content.tid` |
| 人名 | 用户邮箱（uid） | `popo_userinfo_search` | `content.uid` |
| POPO 账号（uid） | **无需解析** | — | 直接使用 |

> **POPO 账号（uid）识别规则**
>
> POPO 系统中用户的唯一标识（uid）有两种格式：`xxx@corp.netease.com` 或 `xxx@mesg.corp.netease.com`，**形似邮箱但本质是 POPO 账号**。当用户输入中包含上述任一格式的字符串时：
> - **直接作为 uid 使用**，无需调用 `popo_userinfo_search` 解析
> - 可直接用于 `receiver`、`contactList`、`uidList`、`inviteList`、`toUids` 等参数
>
> 仅当用户提供的是**中文姓名**（如"张三"）时，才需要通过 `popo_userinfo_search` 查询获取 uid。

**解析命令模板（直接复用，替换关键词即可）：**

```bash
# 搜索人名 → 获取邮箱（uid）
popo-cli popo userinfo_search query=张三 type=2 page=0 pageSize=10 searchRange=1 includeRobot=true

# 搜索群名 → 获取群 ID（tid）
popo-cli popo team_search query=项目讨论群 type=3 page=0 pageSize=10
```

> ⚠️ **参数名是 `query`**（不是 `keyword`）。`type` 和 `page` 为必填参数，缺少会报错。
>
> 群名和人名的解析可**并行执行**。

### 操作确认

- **创建群组**、**邀请成员**：可直接执行，无需额外确认
- **移除成员**、**修改群名**：属于破坏性操作，执行前**必须与用户确认**

### 结果反馈

操作完成后，按以下格式回复：

```
✅ [操作描述]

- 群名：<群名>
- 群 ID：<tid>
- [操作特定信息，如入群人数、需审批人员等]
```

### 错误处理

1. `popo-cli` 返回错误时，查看返回的错误信息
2. 禁止自行尝试替代方案，将错误信息报告给用户
3. 常见错误：权限不足、群不存在、成员已在群中/不在群中

## 被组合调用

popo-im 可以被其他 skill（如 `work-summary`）组合调用。被组合调用时：

- 调用方提供的 `timeStart` / `timeEnd` 毫秒时间戳**直接使用，不要重新推算**
- 回复格式改为交接语气（详见 [workflow.md](references/workflow.md) § 组合调用输出格式）

## 消息搜索交付检查

完成消息搜索后、在生成最终回复前，确认回复是否按照 [workflow.md](references/workflow.md) 中定义的输出格式组织。
