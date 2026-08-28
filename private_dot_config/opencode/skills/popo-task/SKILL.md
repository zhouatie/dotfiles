---
name: popo-task
description: "POPO 任务一站式管理：创建/更新/删除任务、子任务、查询任务列表与详情、查看评论与日志、登记附件。触发场景：(1) 创建任务 —\"帮我建个任务\"、\"给张三派个任务：写周报，明天下午 5 点截止\"、\"记一条待办：周五前看完云协作 UX 计划表\"，以及任何涉及创建/新建/派发/分配任务的请求；(2) 子任务 —\"在任务 12345 下加 3 个子任务：A、B、C\"、\"给这个任务加个子任务\"；(3) 更新/删除 —\"把任务 12345 的截止时间改到周五\"、\"取消任务 X 的截止时间\"、\"删除任务 12345\"；(4) 查询列表 —\"看下分配给我的任务\"、\"我创建的任务\"、\"我关注的任务\"、\"今天截止的任务\"、\"本周截止的任务\"、\"按项目分组看所有任务\"、\"按执行人分组看本周要做的任务\"、\"已完成的任务\"、\"搜索标题含 X 的任务\"、\"搜一下关于周报的任务\"、\"找标题带上线的任务\"；(5) 任务详情 —\"任务 12345 的详情\"、\"看下这个任务的备注/附件/子任务/进度\"；(6) 评论日志只读 —\"看下这个任务下的评论\"、\"任务 X 的操作日志\"；(7) 附件登记 —\"给任务 12345 加一张图片 a.png\"、\"给任务 X 加一份附件 report.pdf\"、\"把这个云空间链接挂到任务 X 下\"。任务管理特征关键词：执行人、责任人、分配给/派给、完成、进度、子任务、截止、待办、备注、附件、项目（POPO 任务项目，非工程仓库项目）。负向边界（不归本 skill，归 popo-calendar）：含\"开会/会议/会议室/参会人/忙闲/时间段/日程/约会议/碰一下/见个面/聊聊/谈一下\"等会议日程意图；含\"约/订/预订会议室\"等场地预订意图。模糊词\"提醒/到期\"默认归 task（任务的截止提醒），仅在显式带会议/日程关键词时归 calendar。本 skill 不支持：新建项目（POPO 任务项目）、看板/日历/时间线视图、评论写、子任务智能拆解、附件下载 — 遇到这些请求应礼貌拒绝并引导至客户端。"
---

# POPO Task Skill

所有操作通过 Bash 执行 `popo-cli <工具名> key=value` 命令完成。本 skill 暴露 14 个 MCP tool，覆盖 POPO 任务 PRD 一期 MVP。

> **参数值引号规则（跨平台兼容，禁止使用单引号）**
>
> 为确保命令在 bash、CMD、PowerShell 等不同 shell 下均能正确执行，统一使用**双引号**作为引用符：
> - 简单值（无空格、无特殊字符）**不加引号**：`key=value`
> - 含空格、中文或特殊字符的值用**双引号**包裹：`title="周报 Q2"`
> - **macOS / Linux**：JSON 数组/对象用双引号包裹，内部双引号使用 `\"` 转义
> - **Windows**：`\"` 转义在 PowerShell 中不可靠，JSON 数组/对象参数**强制走临时文件**：
>   - **Array/Object 参数** → `@file:` — popo-cli 将文件内容解析为 JSON 值（数组/对象）后传参
>   - **String 参数（含中文/特殊字符）** → `@text:` — popo-cli 读取文件内容作为纯文本字符串传参
>   - 标准流程：PowerShell 对象 → `ConvertTo-Json -Compress` → `[System.IO.File]::WriteAllText` (UTF-8 无 BOM) → `key="@file:$path"` 或 `key="@text:$path"`
>
> ```bash
> # ✅ macOS / Linux — 简单值
> popo-cli popo task_detail taskId=t_12345
>
> # ✅ macOS / Linux — 含中文，双引号包裹
> popo-cli popo task_create title="周报 Q2 提交"
>
> # ✅ macOS / Linux — 数组，双引号包裹 + 内部 \" 转义
> popo-cli popo task_list quickConditions="[\"unfinished\"]"
>
> # ❌ 错误：使用单引号
> popo-cli popo task_list quickConditions='["unfinished"]'
> ```
>
> ```powershell
> # ✅ Windows (PowerShell) — Array 参数：@file: 临时文件
> $arr = @("unfinished")
> $json = ConvertTo-Json -InputObject $arr -Compress
> $tmp = Join-Path $env:TEMP "popo_task_$([guid]::NewGuid().ToString('N')).json"
> try {
>     [System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
>     popo-cli popo task_list navigatorId=all quickConditions="@file:$tmp"
> }
> finally {
>     Remove-Item -Path $tmp -ErrorAction SilentlyContinue
> }
>
> # ✅ Windows (PowerShell) — 多个 quickConditions 值
> $arr = @("unfinished", "this_week_deadline")
> $json = ConvertTo-Json -InputObject $arr -Compress
> # ... 同上 @file: 流程
>
> # ✅ Windows (PowerShell) — 含中文/特殊字符的 String（@text:）
> $title = "周报 Q2 提交"
> $tmp = Join-Path $env:TEMP "popo_task_$([guid]::NewGuid().ToString('N')).txt"
> try {
>     [System.IO.File]::WriteAllText($tmp, $title, [System.Text.UTF8Encoding]::new($false))
>     popo-cli popo task_create title="@text:$tmp" projectId=5175
> }
> finally {
>     Remove-Item -Path $tmp -ErrorAction SilentlyContinue
> }
> ```
>
> 🚫 **Windows 平台绝对禁止**：
> - ❌ `quickConditions="[\"unfinished\"]"` — PowerShell 下 `\"` 不可靠，服务端收到裸字符串
> - ❌ 手工字符串拼接 JSON（`'["' + $a + '","' + $b + '"]'`）
> - ❌ 使用 `Set-Content -Encoding UTF8`（PS 5.1 写 BOM）或 `Out-File`（默认 UTF-16）
> - ❌ `ConvertTo-Json` 把中文转义为 `\uXXXX` 是 JSON 标准合法行为，服务端等价解析，不是问题
>
> > **`@file:` vs `@text:` 语义区别**
> > - `@file:` — popo-cli 读取文件内容，**解析为 JSON 值**（数组/对象），用于 `quickConditions` / `conditions` / `assignees` / `followers` / `attachments` 等 Array/Object 类型参数
> > - `@text:` — popo-cli 读取文件内容，作为**纯文本字符串**传参，用于 `title` / `remark` / `keyword` / `message` 等 String 类型参数
> > - 两者**不可混用**：Array 参数用 `@text:` 传 JSON 字符串会被服务端当成字符串而非数组，导致 `Cannot construct instance of ArrayList`

---

## ⛔ 七条铁律（每次操作前必须检查）

**铁律 1：参数严格按字段表**
所有调用的 popo-cli 命令，**必须**到 [`references/tool-reference.md`](./references/tool-reference.md) 查询相应工具的参数说明，不得随意捏造字段名、字段类型、枚举值。

**铁律 2：7 个写操作必须二次确认（用选项选择器，禁止让用户手动输入）**
`task_create` / `task_subtask_create` / `task_update` / `task_delete` / `task_attachment_add` / `task_finish` / `task_rebuild` **任何**一次调用前，**必须**走"解析 → 回显完整摘要 → **调用 `ask_user_question` 提供选项** → 调接口 → 报告结果"五步，**禁止**省略回显或确认任一环节。即便用户一次性给出完整信息，仍需回显 + `ask_user_question` 确认。**禁止**让用户手动输入"确认/取消"等文字，必须使用选项选择器。各操作确认选项见对应工作流文档。

**补充：何时用 `ask_user_question` vs 何时直接问**
- **用 `ask_user_question`（选择器）**：确认操作（确认/取消）、从候选列表中选一项（如人选二选一、项目多选一）。选项数量固定，用户只需点选。
- **直接聊天问（让用户打字）**：仅当**必填字段缺失**时反问（如"任务标题是什么？"）。内容自由无固定选项，`ask_user_question` 无法提供输入框。
- **可选字段不追问**：执行人（默认当前用户）、截止时间、项目、优先级、关注人、备注等均为可选，用户没给就跳过，不追问。

**铁律 3：删除前必先 `task_detail`，父任务需确认子任务处理方式**
调 `task_delete` 之前必须先 `task_detail`。若为父任务且有子任务，回显询问用户选择"全部删除"（`deleteSubTasks=true`）或"仅删父任务"（`deleteSubTasks=false`，子任务升级为独立任务）；普通任务/子任务直接确认后调用。详见 `tool-reference.md` §6。

**铁律 4：时间单位不统一，严格按 contract 区分；显示时必须程序化换算、严禁心算**
- ⛔⛔ **展示任何服务端返回的时间戳（截止/开始/创建/完成/操作时间等）前，必须用命令换算成本地时区可读格式，严禁凭锚点手推日期。** 标准换算命令见 [`references/task-detail-render.md` §5.0](./references/task-detail-render.md#50-标准换算命令复制即用一次批量转多个)（`node`/`date` 输出字符串直接填，禁止对结果再手工加减）。
- **写操作入参**（create/update/subtask）：`startTime`/`deadline`/`alarmTimestamp` 一律 **毫秒**
- **`task_list` 返回** (McpTaskItem)：`startTime`/`deadline`/`createTime` 为**毫秒**（换算直接传）；任务级 `completeTime` **恒 null**（取 `assignees[].completeTime` 毫秒）
- **`task_search` 返回** (AgentQueryTaskItem)：`startTime`/`deadline`/`createTime` 为**秒**（换算前 **×1000**），`completeTime` 为**毫秒**
- **`task_detail` 返回** (TaskVo)：全部**毫秒**
- **评论/日志** (EditRecord)：`timestamp`/`newDeadline` 等全部**毫秒**
- `deadlineFormat`：`0`=未设、`1`=仅日期、`2`=日期+时间
- `completeCondition`：`"all"`=所有执行人完成才算完成，`"any_one"`=任意一人完成即算完成
- **与 popo-calendar 的 ISO-8601 完全不同**。Agent 端以 contract.yaml 每个字段描述为准决定 `* 1000` 与否。

⚠️ **`task_update` 独占陷阱**：`assignees`/`followers` 为**全量替换**（不传=不更新，传空数组=清空）；`projectId` 传 `0` 表示从项目移出变为个人任务。

**铁律 5：本期不暴露的能力**
以下能力一期**不**做，遇到请求**礼貌拒绝**并引导至 POPO 客户端，**不**尝试任何 popo-cli 工具调用：
- 新建项目（POPO 任务项目）
- 看板 / 日历 / 时间线视图
- 评论写、修改、删除
- 子任务智能拆解
- 附件下载
- 修改循环规则（`rrule`）：skill 入口不暴露，用户说"改重复规则/设循环"时引导至客户端
- 修改提醒（`alarm`）：skill 入口不暴露，用户说"改提醒/设闹钟"时引导至客户端

**铁律 6：读操作调用前必读对应工作流 + 渲染条约**
- ⛔ **任何读操作（`task_list` / `task_search` / `task_detail` / `task_comment_list` / `task_log_list`）调用前，必须先读对应工作流文档**，按工作流构造入参、渲染结果、处理分页。**禁止**仅凭 SKILL.md 速查表/示例或字段表直接拼命令调用，否则会丢失渲染规范、时间换算、分页字段差异等关键约束。对应关系：
  - `task_list` / `task_search` → [`task-list-workflow.md`](./references/task-list-workflow.md)：入参构造 + 表格 10 列规范 + 父子树形缩进 + 分页字段差异 + 默认隐藏已完成
  - `task_detail` → [`task-detail-render.md`](./references/task-detail-render.md)：11 段段落顺序 + 时间换算 + 优先级严格映射 + 附件/子任务渲染 + §5.0 标准换算命令
  - `task_comment_list` / `task_log_list` → [`task-comment-log-view.md`](./references/task-comment-log-view.md)：评论回复/删除判定 + POPO 标签纯文本解析 + eventType 文案映射 + AI 标识（`aiOperated=true` 加 ✦）+ 时间换算
- ⛔ **`task-detail-render.md §5.0` 标准换算命令被所有含时间戳的读操作共用**（列表/详情/评论/日志）。跳读 `task-detail-render.md` 会导致时间戳原样输出或心算（违反铁律 4），且列表/评论/日志的时间换算命令也拿不到。

**`task_list` / `task_search` 专属：默认隐藏已完成任务**
- ⛔ **默认隐藏已完成任务**（用户未提及完成状态时）：`quickConditions` 中**必须**追加 `unfinished`，作为实现细节透明执行，**不**向用户提及"已加 unfinished"。该规则同时适用于 `task_list` 与 `task_search`。
- 用户主动表达完成状态时按语义传参（**三档**，禁止混用）：
  - 「看已完成」/「我已经完成的」/「已完成」快捷筛选 /「历史任务」 → `quickConditions=["finished"]`（**仅**已完成，移除 `unfinished`）
  - 「包含已完成任务」/「全部都看（含已完成）」/「已完成的也一起看」 → `quickConditions` **既不含 `finished` 也不含 `unfinished`**（已完成+未完成都展示）
  - 默认（用户未提完成状态） → `quickConditions=["unfinished"]`（仅未完成）
- 与其他 quickConditions 叠加时同样遵循上述三档：默认场景把 `unfinished` 与其他值一起放进数组（如 `["unfinished","this_week_deadline"]`）；「包含已完成」场景则只放其他值、不放 `unfinished`/`finished`。

**铁律 7：Windows 平台数组/对象参数强制走 @file: / @text: 临时文件（每次构造 popo-cli 命令前必检）**
- ⛔ **Windows (PowerShell) 下绝对禁止**用 `\"` 转义 JSON 数组/对象参数（如 `assignees="[\"uid\"]"`），PowerShell 不识别 `\"` 转义语义，会原样传递导致服务端收到字符串而非数组，触发 `Cannot construct instance of ArrayList` 错误
- ✅ Array/Object 参数（`assignees` / `followers` / `quickConditions` / `conditions` / `attachments` 等）→ **`@file:`** 临时文件标准流程：
  ```powershell
  $arr = @("value1", "value2")
  $json = ConvertTo-Json -InputObject $arr -Compress
  $tmp = Join-Path $env:TEMP "popo_task_$([guid]::NewGuid().ToString('N')).json"
  try {
      [System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
      popo-cli popo <tool> <other_params> arrayParam="@file:$tmp"
  }
  finally {
      Remove-Item -Path $tmp -ErrorAction SilentlyContinue
  }
  ```
- ✅ String 参数含中文/特殊字符 → **`@text:`** 临时文件；ASCII 纯字符串可直传
- 🚫 禁止 `ConvertTo-Json` 后手工拼接 shell 字符串、禁止 `Set-Content -Encoding UTF8`（PS 5.1 带 BOM）、禁止 `Out-File`（默认 UTF-16）
- 详细示例见 §参数值引号规则 Windows 部分

---

## NEVER DO

- 不要直接创建、更新、删除任务或登记附件；必须用 `ask_user_question` 让用户选择确认后才允许执行（铁律 2）
- **不要用 `ask_user_question` 反问缺失信息**（如"补一下标题"、"父任务 ID 是？"）。`ask_user_question` 无输入框，选了"输入提供XX"也没用。反问时直接聊天问，用户打字回复。
- 不要猜测 `taskId` / `projectId` / `uid` 等 ID，必须从接口获取或用户提供
- 不要使用 curl / python 直接调任务接口，统一用 `popo-cli`（附件上传时的 curl/curl.exe 除外）
- 不要把时间传成 ISO-8601 字符串；写操作入参一律毫秒时间戳
- 不要为子任务自动填创建人本人为执行人（仅 `task_create` 在未指定执行人时填）
- 不要在分组聚合时用 `assigner`（分配人/创建人单值）作"执行人"维度；执行人分组必须展开 `McpTaskItem.assignees[]` 多值数组
- 不要主动把 `quickConditions.unfinished` / `conditions.createTime` / `conditions.finished` 作为**用户语义入口**暴露（即不向用户宣传"你可以用 unfinished 筛选"）；`unfinished` 是**内部默认必带**的实现细节（铁律 6），不冲突
- 不要尝试调用未暴露的 tool（如新建项目等铁律 5 列项）；`task_finish` / `task_rebuild` **已放开支持**，按 [task-create-workflow.md §4](./references/task-create-workflow.md#4-完成任务task_finish--重开任务task_rebuild) 走二次确认工作流
- **不要创建任务时追问父任务**：`task_create` 无 `parentTaskId` 字段，只有 `task_subtask_create` 才需要父任务。用户没说"子任务/加子任务"就不问父任务。
- **不要修改循环规则和提醒**：skill 不暴露 `rrule` / `alarm` 入口，遇到相关请求引导至客户端。
- 不要跨 skill 复用 `popo_calendar_user_info` / `popo_team_current_user_info` 来拿当前用户；本 skill 用 `task_user_info`
- ⛔ **不要在未读取对应工作流文档的情况下直接调任何读操作**（铁律 6）—— `task_list`/`task_search` 必读 `task-list-workflow.md`，`task_detail` 必读 `task-detail-render.md`，`task_comment_list`/`task_log_list` 必读 `task-comment-log-view.md`。速查表/示例仅供路由参考，调用前必须读工作流拿到渲染规范、时间换算、分页字段等约束
- ⛔ **不要在用户未提及完成状态时省略 `quickConditions=["unfinished"]`**（铁律 6）—— `task_list`/`task_search` 默认必须隐藏已完成任务；只在用户主动表达完成状态时按三档语义调整
- ⛔ **不要在写操作返回 `status=100403`（无权限）时模糊兜底或重试**—— 必须解析 `message` 中的 `taskId`/`required`/`action`，明确提示用户无权限原因 + 联系任务创建者/管理员（见「错误处理」）。读操作 `status=110200` 同理明确提示，不重试
- ⛔ **不要把无权限当"网络异常/服务不可用"报告**—— 100403/110200 是业务态而非网络错误，模糊提示会误导用户重试
- ⛔ **Windows 平台禁止在 shell 中用 `\"` 转义 JSON 数组/对象参数**—— 必须走 `@file:` 临时文件（Array/Object）或 `@text:` 临时文件（含中文的 String）。ASCII 纯字符串可直传

---

## 当前用户获取

需要"默认填我为执行人"等语义时，**先调 `task_user_info`** 拿当前 uid：

```bash
popo-cli popo task_user_info
# 返回 {uid, name, email, deptName}
```

> ⚠️ "我创建的 / 我关注的 / 分配给我"查询**无需** `task_user_info`，直接用 `task_list navigatorId=creator/follower/assignee`，服务端按当前用户翻译。仅"查指定他人"创建/关注的任务时才需拿对方 uid。
> ⚠️ 不要用 `popo_calendar_user_info` 或其他 skill 的当前用户接口替代；skill 自给自足。

---

## 工作流总览

| 操作 | 主 tool | 工作流文档 |
|---|---|---|
| 创建任务 | `task_create` | [task-create-workflow.md](./references/task-create-workflow.md#1-创建任务task_create完整步骤) ⚠️ **无需父任务**，非子任务场景不追问 parentTaskId |
| 创建子任务 | `task_subtask_create` | [task-create-workflow.md](./references/task-create-workflow.md#2-创建子任务task_subtask_create) ⚠️ **需要父任务**，必须指定 parentTaskId |
| 更新任务 | `task_update` | [task-create-workflow.md](./references/task-create-workflow.md#3-更新任务task_update完整步骤) |
| 删除任务 | `task_delete` | 见铁律 3 + [tool-reference §6](./references/tool-reference.md#6-task_delete--删除任务写操作-) |
| 完成任务 | `task_finish` | [task-create-workflow.md §4.1](./references/task-create-workflow.md#41-完成任务task_finish) ⚠️ 写操作二次确认（铁律 2）；标记整个任务完成 |
| 重开任务 | `task_rebuild` | [task-create-workflow.md §4.2](./references/task-create-workflow.md#42-重开任务task_rebuild) ⚠️ 写操作二次确认（铁律 2）；已完成→未完成 |
| 列表查询（浏览） | `task_list` | ⛔ **[task-list-workflow.md](./references/task-list-workflow.md) — 调用前必读（铁律 6）**。四大快捷方式 navigatorId=all/assignee/follower/creator；默认必带 `quickConditions=["unfinished"]` 隐藏已完成 |
| 关键词搜索 | `task_search` | ⛔ **[task-list-workflow.md §0/§3/§8.2](./references/task-list-workflow.md) — 调用前必读（铁律 6）**。**keyword 必填**，分页用 `scrollId`；默认必带 `quickConditions=["unfinished"]` 隐藏已完成；**`pageSize=50` 拉满 + 首页无完整匹配自动续拉兜底（上限 3 页）+ 本地按 token 命中数重排**（§8.2） |
| 任务详情 | `task_detail` | ⛔ **[task-detail-render.md](./references/task-detail-render.md) — 调用前必读（铁律 6）**。11 段段落顺序 + 时间换算 + 优先级映射 + §5.0 标准换算命令（列表/评论/日志共用） |
| 评论只读 | `task_comment_list` | ⛔ **[task-comment-log-view.md](./references/task-comment-log-view.md#1-评论渲染) — 调用前必读（铁律 6）**。评论回复/删除判定 + POPO 标签纯文本解析 |
| 日志只读 | `task_log_list` | ⛔ **[task-comment-log-view.md](./references/task-comment-log-view.md#2-日志渲染) — 调用前必读（铁律 6）**。eventType 文案映射 + `aiOperated=true` 加 ✦ 标识 |
| 附件登记 | `task_attachment_add` | [task-attachment-upload-workflow.md](./references/task-attachment-upload-workflow.md) |
| 项目搜索/列出 | `task_project_search` | [task-create-workflow.md §1.2](./references/task-create-workflow.md#12-项目名--projectid-解析子流程) |
| 当前用户 | `task_user_info` | 上节"当前用户获取" |

> **查任务选接口**：有关键词/模糊标题匹配（"搜 X"、"找标题带 X 的任务"）→ `task_search`（keyword 必填）；纯浏览（四大快捷方式 navigatorId 或某项目全部任务）→ `task_list`。两接口分页字段不同：`task_list` 用 `nextPageToken`，`task_search` 用 `scrollId`。
>
> ⛔ **`task_search` 自动续拉兜底（§8.2）**：服务端 ES `match` 查询分词 OR 匹配 + 按 `createTime` 倒序（非相关度），首页 20 条易全是"部分匹配但更新"的任务。skill **必须**：(1) `pageSize=50` 拉满；(2) 首页无完整 token 命中时自动续拉（上限 3 页/150 条）；(3) 本地按 token 命中数重排（完整匹配置顶）。详见 [`task-list-workflow.md §8.2`](./references/task-list-workflow.md)。
>
> ⛔ **无论选哪个接口，调用前都必须先读 [`references/task-list-workflow.md`](./references/task-list-workflow.md)**（铁律 6）：拿全表格列规范（§7）、父子树形缩进（§7.2）、分页字段差异（§8）、默认隐藏已完成（§6）等约束。仅看 SKILL.md 速查表/示例直接调命令会丢失这些约束。
>
> ⛔ **默认隐藏已完成任务**（铁律 6）：用户未提及完成状态时，`quickConditions` 必须追加 `unfinished`（不向用户提及）；用户主动表达完成状态时按三档语义调整（见铁律 6）。

---

## 工具速查

| 操作 | tool | 参考 |
|---|---|---|
| 当前用户 | `task_user_info` | [详情](./references/tool-reference.md#1-task_user_info--获取当前用户) |
| 项目搜索/列出 | `task_project_search` | [详情](./references/tool-reference.md#2-task_project_search--项目搜索--列出) |
| 创建任务 | `task_create` | [详情](./references/tool-reference.md#3-task_create--创建任务写操作-) |
| 创建子任务 | `task_subtask_create` | [详情](./references/tool-reference.md#4-task_subtask_create--创建子任务写操作-) |
| 更新任务 | `task_update` | [详情](./references/tool-reference.md#5-task_update--更新任务写操作-) |
| 删除任务 | `task_delete` | [详情](./references/tool-reference.md#6-task_delete--删除任务写操作-) |
| 完成任务 | `task_finish` | [详情](./references/tool-reference.md#12-task_finish--完成任务写操作-) |
| 重开任务 | `task_rebuild` | [详情](./references/tool-reference.md#13-task_rebuild--重开任务写操作-) |
| 任务详情 | `task_detail` | [详情](./references/tool-reference.md#7-task_detail--任务详情) |
| 任务列表（浏览） | `task_list` | [详情](./references/tool-reference.md#8-task_list--任务列表浏览四大快捷方式--项目内) |
| 关键词搜索 | `task_search` | [详情](./references/tool-reference.md#8b-task_search--关键词搜索任务) |
| 评论只读 | `task_comment_list` | [详情](./references/tool-reference.md#9-task_comment_list--评论只读) |
| 日志只读 | `task_log_list` | [详情](./references/tool-reference.md#10-task_log_list--日志只读) |
| 附件登记 | `task_attachment_add` | [详情](./references/tool-reference.md#11-task_attachment_add--附件登记写操作-) |

---

## 错误处理

- `popo-cli` 命令报错时查看错误信息，按需重试或报告给用户（不暴露内部细节）
- 服务端 12 个接口在 test 环境未就绪时，可能返回 4xx/5xx — 报告"任务服务暂不可用，请稍后重试"
- 认证失败（401/403）→ 检查环境变量 `uid` / fabric 登录状态
- 类型解析错误（`Cannot construct instance of ArrayList`、`JSON parse error`）→ 按平台分叉（铁律 7）：
  - **Windows**：**禁止** HTTP 直传兜底（同样受 PowerShell 引号问题影响），**必须**用 `@file:` 临时文件重试
  - **macOS/Linux**：检查 `\"` 转义是否正确，或改用 HTTP 直传

### 无权限处理（写操作铁律，contract 权限检查）

写操作（`task_create` / `task_subtask_create` / `task_update` / `task_delete` / `task_finish` / `task_rebuild` / `task_attachment_add`）在 MCP 层调用下游 Service 前会先做权限校验（复用 `ITaskPermService.check`，底层 OpenFGA）。**无权限时直接 fail-fast，不写库**，返回 HTTP 200 + `status=100403`，`message` 为结构化文本：

```
无权限操作任务 [taskId=<id>, required=<CAN_EDIT|CAN_COMPLETE>, action=<动作名>]
```

**处理规则**（所有写操作调用后必查）：

1. 解析响应 body 的 `status` 与 `message`：
   - `status=100403` → 命中无权限分支
   - 从 `message` 中提取 `taskId` / `required` / `action` 三个字段（正则或字符串切片均可）
2. **明确提示用户**，禁止模糊兜底（不报"网络异常""请稍后重试"），禁止重试同一操作。提示模板：

   > ⛔ 无权限执行此操作
   > 任务 ID：`<taskId>`
   > 所需权限：`<required>`（`CAN_EDIT`=编辑权 / `CAN_COMPLETE`=完成权）
   > 操作类型：`<action>`（如 update / delete / finish / rebuild / create_subtask / add_attachment）
   > 请联系任务**创建者**或**项目管理员**申请对应权限后重试。

3. 各写操作所需权限对照（contract 权威）：

   | action          | required     | 校验对象             |
   |-----------------|--------------|----------------------|
   | `create_subtask`  | `CAN_EDIT`    | parentTaskId（父任务）|
   | `update`          | `CAN_EDIT`    | taskId              |
   | `delete`          | `CAN_EDIT`    | taskId              |
   | `finish`          | `CAN_COMPLETE`| taskId              |
   | `rebuild`         | `CAN_COMPLETE`| taskId              |
   | `add_attachment`  | `CAN_EDIT`    | taskId              |

   > ⚠️ `task_create` 不在表中（新建任务无前置 taskId 可校验，权限走 fabric 登录态），但仍按通用写操作铁律处理：若返回 100403 同样解析 message 提示。

### 读操作无权限（下游 canAccessTask）

读操作（`task_detail` / `task_list` / `task_search` / `task_comment_list` / `task_log_list` / `task_project_search` / `task_user_info`）不在 MCP 层拦截，依赖下游 service 内部 `canAccessTask` 校验。无权限时下游返回 `status=110200`（`TODO_OPERATION_FORBIDDEN`）。

处理：解析到 `status=110200` 时，提示用户"无权限访问该任务（taskId=<X>），可能不是该任务的相关人员，请联系任务创建者或项目管理员"。**不重试**。

## 详细参考

- [references/tool-reference.md](./references/tool-reference.md) — 12 个 tool 全部参数与返回值
- [references/task-create-workflow.md](./references/task-create-workflow.md) — 创建/更新/子任务工作流
- [references/task-list-workflow.md](./references/task-list-workflow.md) — task_list 浏览（四大快捷方式）+ task_search 搜索 + Agent 端分组
- [references/task-attachment-upload-workflow.md](./references/task-attachment-upload-workflow.md) — 三通道附件上传
- [references/task-detail-render.md](./references/task-detail-render.md) — 详情渲染规范
- [references/task-comment-log-view.md](./references/task-comment-log-view.md) — 评论/日志只读渲染
