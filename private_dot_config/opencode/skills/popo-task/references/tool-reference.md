# POPO Task — 工具参考（11 个 MCP tool）

> 本文档为 `popo-task` skill 的工具字段权威来源，所有调用必须按此文档列出的参数名 / 类型 / 必填性传参，**不得擅自捏造字段**。

## 通用约定

### 跨平台参数引号规则（与 popo-calendar 同款，禁止单引号）

为确保命令在 bash、CMD、PowerShell 等不同 shell 下均能正确执行，统一使用**双引号**：

- 简单值（无空格、无特殊字符）**不加引号**：`key=value`
- 含空格 / 中文 / 特殊字符的值用**双引号**包裹：`title="周报 Q2"`
- JSON 数组/对象用**双引号**包裹，内部双引号使用 `\"` 转义：
  `assignees="[\"uid_a\",\"uid_b\"]"`

```bash
# ✅ 简单值
popo-cli popo task_detail taskId=12345

# ✅ 含中文 — 双引号包裹
popo-cli popo task_create title="周报 Q2 提交"

# ✅ 数组 — 双引号包裹 + 内部 \" 转义
popo-cli popo task_create title="周报" assignees="[\"a@corp.com\",\"b@corp.com\"]"

# ❌ 错误：使用单引号（Windows CMD 不支持）
popo-cli popo task_create title='周报' assignees='["a@corp.com"]'
```

服务端若回类型解析错误（`Cannot construct instance of java.util.ArrayList` 等），改用 HTTP 直传：

```bash
popo-cli call POST /api/v1/open-apis/gateway/appcode/popo/_invoke \
  --body "{\"tool\":\"task_create\",\"params\":{\"title\":\"周报\",\"assignees\":[\"a@corp.com\"]}}"
```

### 时间值规范

**时间单位不统一，严格按 contract.yaml 的描述区分**：

| 接口/方向 | 字段 | 单位 | 说明 |
|------|------|:--:|------|
| 写操作入参（create/update/subtask） | `startTime`、`deadline`、`alarmTimestamp` | **毫秒** | 与 contract Form 定义一致 |
| `task_list` (McpTaskItem) | `startTime`、`deadline`、`createTime` | **毫秒** | 来源 ListViewTaskItemVo（= PO 秒值 ×1000），MCP 层透传 |
| `task_list` (McpTaskItem) | `completeTime`（任务级） | — | **恒 null**，取 `assignees[].completeTime` |
| `task_list` (McpTaskItem) | `assignees[].completeTime` | **毫秒** | 来源 TodoListPO.finishTime ×1000 |
| `task_search` (AgentQueryTaskItem) | `startTime`、`deadline`、`createTime` | **秒** | 来源 PO 秒级字段，MCP 层透传 |
| `task_search` (AgentQueryTaskItem) | `completeTime` | **毫秒** | 来源 TodoInfoPO.completeTime（毫秒） |
| `task_search` (AgentQueryTaskItem) | `assignees[].completeTime` | **秒** | 来源 TodoListPO.finishTime（秒） |
| `task_detail` (TaskVo) | `startTime`、`deadline`、`taskCreateTime` | **毫秒** | — |
| 评论/日志 (EditRecord) | `timestamp` | **毫秒** | record.timestamp.toEpochMilli() |
| 评论/日志 (EditRecordDetail) | `newDeadline`、`newStartTime` 等 | **毫秒** | — |
| 评论/日志 (EditRecordDetail) | `commentId` | int64 | — |

> **与 popo-calendar 的 ISO-8601 完全不同**。Agent 端转换时以 contract.yaml 每个字段描述为准：标注"秒"→ `ts * 1000`，标注"毫秒"→ 直接用。

### 写操作铁律

**5 个写操作**（`task_create` / `task_subtask_create` / `task_update` / `task_delete` / `task_attachment_add`）**必须**走"解析 → 回显完整摘要 → **调用 `ask_user_question` 提供选项让用户选择确认或取消** → 调接口 → 报告结果"五步，**禁止**省略任一环节。**禁止**让用户手动输入"确认/取消"等文字，必须使用选项选择器。

> ⚠️ `task_attachment_add` 特殊：确认步骤在**上传文件之前**执行（非上传后），避免用户取消造成无效上传。详见 [`task-attachment-upload-workflow.md`](./task-attachment-upload-workflow.md)。

### 写操作无权限响应处理（contract 权限检查）

写操作在 MCP 层调用下游 Service 前会先做权限校验（`ITaskPermService.check` / OpenFGA）。**无权限时直接 fail-fast，不写库**，返回 HTTP 200 + `status=100403`，`message` 结构化：

```
无权限操作任务 [taskId=<id>, required=<CAN_EDIT|CAN_COMPLETE>, action=<动作名>]
```

**处理流程**（所有写操作调用后必查 `status` 字段）：

1. `status=100403` → 命中无权限分支，**不重试**，按下面模板提示用户
2. 从 `message` 提取 `taskId` / `required` / `action`（正则示例：`taskId=(\d+), required=(CAN_EDIT|CAN_COMPLETE), action=(\w+)`）
3. **明确提示**（禁止模糊兜底为"网络异常/请稍后重试"）：

   > ⛔ 无权限执行此操作
   > 任务 ID：`<taskId>`
   > 所需权限：`<required>`（`CAN_EDIT`=编辑权 / `CAN_COMPLETE`=完成权）
   > 操作类型：`<action>`
   > 请联系任务**创建者**或**项目管理员**申请对应权限后重试。

**各写操作所需权限对照（contract 权威）**

| action          | required     | 校验对象             |
|-----------------|--------------|----------------------|
| `create_subtask`  | `CAN_EDIT`    | parentTaskId（父任务）|
| `update`          | `CAN_EDIT`    | taskId              |
| `delete`          | `CAN_EDIT`    | taskId              |
| `finish`          | `CAN_COMPLETE`| taskId              |
| `rebuild`         | `CAN_COMPLETE`| taskId              |
| `add_attachment`  | `CAN_EDIT`    | taskId              |

> ⚠️ `task_create` 不在表中（新建任务无前置 taskId 可校验，权限走 fabric 登录态）。若返回 100403 同样解析 `message` 提示。

**读操作无权限**（下游 `canAccessTask`）：返回 `status=110200`（`TODO_OPERATION_FORBIDDEN`）。处理：提示"无权限访问该任务（taskId=<X>），可能不是该任务的相关人员，请联系任务创建者或项目管理员"，**不重试**。

---

## 1. `task_user_info` — 获取当前用户

**方法**：GET。**入参**：无。

**返回**

| 字段 | 类型 | 说明 |
|---|---|---|
| `uid` | string | 当前用户 POPO 账号（如 `alice@corp.netease.com`），用于 `conditions[assigner/follower]` |
| `name` | string | 中文显示名 |
| `email` | string | 邮箱（通常与 uid 一致） |
| `deptName` | string | 部门名 |

**用途**：解析"我创建的 / 我关注的"、为 `task_create` 默认填 `assignees=[<uid>]`、回显时识别"自己"语义。

```bash
popo-cli popo task_user_info
```

> ⚠️ **不要**用 `popo_calendar_user_info` / `popo_team_current_user_info` 代替，skill 自给自足。

---

## 2. `task_project_search` — 项目搜索 / 列出

**入参**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `keyword` | string | ❌ | 项目名关键字。**可空**：不传或空串 → 走 DB 全量分支，返回当前用户可见的全部项目（按可见项目排序，**不含项目分组**）；非空 → 走 ES 搜索按名称匹配。**禁止**用"我"、"你"等代词当 keyword |
| `pageSize` | int | ❌ | 单页条数，默认 20，最大 50 |
| `pageToken` | string | ❌ | 续拉游标（等于服务端 `scrollId`） |

**返回**

| 字段 | 类型 | 说明 |
|---|---|---|
| `list[].projectId` | string | 项目唯一 ID，用于 `task_create.projectId` 或 `conditions[project]` |
| `list[].name` | string | 项目显示名 |
| `list[].ownerUid` | string | 项目负责人 uid |
| `more` | bool | true 表示还有下一页，用 `pageToken` 续拉 |
| `pageToken` | string | 下一页 token |
| `searchId` | string | 搜索 id（仅 `keyword` 非空时返回，同一关键词翻页时回传） |

**两种调用模式**

| 模式 | 入参 | 用户语义 | 返回 |
|---|---|---|---|
| 列出全部 | 不传 `keyword` | "我的项目 / 看下我有哪些项目 / 列出项目" | 当前用户可见的全部项目（不含项目分组） |
| 按名搜索 | `keyword=<项目名>` | 用户报具体项目名，解析为 projectId | 名称匹配的项目列表 |

**匹配处理（按名搜索模式）**：唯一 → 直接用；多匹配且 `name == keyword` → 取该项；其余多匹配 → 列候选；零匹配 → 提示用户去客户端建项目并终止当前流程。

---

## 3. `task_create` — 创建任务（写操作 ⛔）

**入参**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `title` | string | ✅ | 任务标题（缺失则反问，不得自动生成） |
| `projectId` | int64 | ❌ | 所属项目 ID，先经 `task_project_search` 解析 |
| `assignees` | string[] | ❌ | 执行人 uid 列表；**未指定时默认 `[<task_user_info.uid>]`**（创建任务唯一默认；子任务不适用） |
| `followers` | string[] | ❌ | 关注人 uid 列表 |
| `priority` | int | ❌ | 优先级：`0`=无 `1`=紧急 `2`=高 `3`=中 `4`=低 |
| `deadline` | int64 | ❌ | 截止时间（**入参毫秒**，写操作一律毫秒）；`0` 表示清空 |
| `deadlineFormat` | int | ❌ | 截止粒度：`0`=未设 `1`=仅日期 `2`=日期+时间 |
| `startTime` | int64 | ❌ | 开始时间（**入参毫秒**）；`0` 表示清空 |
| `remark` | string | ❌ | 备注 |
| `rrule` | string | ❌ | 循环规则（iCal RRULE），空串 `""` 表示清空 |
| `alarm` | object | ❌ | 提醒对象（见下） |

**`alarm` 子对象**

| 字段 | 类型 | 说明 |
|---|---|---|
| `alarmTimestamp` | int64 | 提醒时刻（**入参毫秒**） |
| `alarmType` | int | 提醒类型 |

**返回**

| 字段 | 类型 | 说明 |
|---|---|---|
| `taskId` | string | 新建任务 ID |

**示例**

```bash
# 单执行人 + 截止
popo-cli popo task_create title="周报 Q2 提交" \
  assignees="[\"alice@corp.com\"]" \
  deadline=1735660800000 deadlineFormat=2 priority=2

# 多执行人 + 多关注人 + 提醒
popo-cli popo task_create title="联调验收" \
  assignees="[\"alice@corp.com\",\"bob@corp.com\"]" \
  followers="[\"carol@corp.com\"]" \
  alarm="{\"alarmTimestamp\":1735660800000,\"alarmType\":1}"
```

---

## 4. `task_subtask_create` — 创建子任务（写操作 ⛔）

**入参**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `parentTaskId` | int64 | ✅ | 父任务 ID（缺失则反问） |
| `title` | string | ✅ | 子任务标题 |
| `assignees` | string[] | ❌ | 执行人 uid；不传则默认当前用户 |
| `followers` | string[] | ❌ | 关注人 |
| `priority` | int | ❌ | 同 `task_create` |
| `deadline` / `deadlineFormat` / `startTime` / `remark` | — | ❌ | 同 `task_create` |

> **项目继承**：子任务**自动继承**父任务的 `projectId`，**禁止**传 `projectId`。

```bash
popo-cli popo task_subtask_create parentTaskId=t_12345 title=A
popo-cli popo task_subtask_create parentTaskId=t_12345 title=B
popo-cli popo task_subtask_create parentTaskId=t_12345 title=C
```

---

## 5. `task_update` — 更新任务（写操作 ⛔）

**入参**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `taskId` | int64 | ✅ | 目标任务 ID |
| `title` | string | ❌ | 新标题，不传则不更新 |
| `priority` | int | ❌ | 优先级 0/1/2/3/4，不传不更新 |
| `remark` | string | ❌ | 备注，不传不更新 |
| `startTime` | int64 | ❌ | 开始时间毫秒戳；**`0` 表示删除已有开始时间** |
| `deadline` | int64 | ❌ | 截止时间毫秒戳；**`0` 表示删除已有截止时间** |
| `deadlineFormat` | int | ❌ | 截止时间格式，配合 `deadline` 传 |
| `rrule` | string | ❌ | 重复规则。**skill 不暴露此入口**，用户请求引导至客户端 |
| `alarm` | object | ❌ | 提醒设置。**skill 不暴露此入口**，用户请求引导至客户端 |
| `completeCondition` | string | ❌ | `"all"`=所有执行人完成才算完成，`"any_one"`=任意一人完成即算完成 |
| `assignees` | array | ❌ | 执行人 uid 数组；**全量替换**（传空数组表示清空所有执行人），不传则不更新 |
| `followers` | array | ❌ | 关注人 uid 数组；**全量替换**（传空数组表示清空所有关注人），不传则不更新 |
| `projectId` | int64 | ❌ | 所属项目 ID；**`0` 表示从项目移出变为个人任务**，不传则不更新 |

**清空语义对照表**

| 字段 | 清空值 |
|---|---|
| `deadline` | `0` |
| `startTime` | `0` |

**示例**

```bash
# 单字段 — 改截止
popo-cli popo task_update taskId=t_12345 deadline=1735747200000 deadlineFormat=2

# 多字段
popo-cli popo task_update taskId=t_12345 title="新标题" priority=3

# 清空截止
popo-cli popo task_update taskId=t_12345 deadline=0
```

---

## 6. `task_delete` — 删除任务（写操作 ⛔）

**入参 `McpTaskDeleteForm`**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `taskId` | int64 | ✅ | 目标任务 ID |
| `deleteSubTasks` | boolean | ❌ | 仅父任务生效；默认 `false`=仅删父任务子任务升级为独立任务，`true`=父子全删。子任务/普通任务忽略此字段 |

**删除前二次确认流程**

1. 先调 `task_detail` 获取 `isParent` 和 `subtask` 列表
2. 若 `isParent=true` 且有子任务，调用 `ask_user_question` 提供选项：
   > 该任务下有 N 个子任务
   ├─ 选项：["全部删除（含 N 个子任务）", "仅删父任务（子任务升级为独立任务）", "取消"]
   ├─ 选「全部删除」→ `deleteSubTasks: true`
   ├─ 选「仅删父任务」→ `deleteSubTasks: false`
   └─ 选「取消」→ 终止操作
3. 若为普通任务/子任务，调用 `ask_user_question` 提供选项：["确认删除", "取消"]
4. 用户确认后调接口，报告结果
   - 成功 → 回显"任务 <taskId> 已删除"
   - `status=100403`（无权限，required=CAN_EDIT，校验对象=taskId）→ 解析 message 中的 taskId/required/action，
     明确提示"无权限删除任务 <taskId>，所需权限 CAN_EDIT，请联系任务创建者/管理员"，**不重试**
   - 其他错误 → 报告服务端错误信息（不暴露内部细节）

**示例**

```bash
# 仅删除父任务，子任务升级为独立任务（默认）
popo-cli popo task_delete taskId=12345 deleteSubTasks=false

# 父子全删
popo-cli popo task_delete taskId=12345 deleteSubTasks=true

# 普通任务删除
popo-cli popo task_delete taskId=67890
```
```

---

## 7. `task_detail` — 任务详情

**入参**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `taskId` | int64 | ✅ | 目标任务 ID |

**返回 `McpTaskDetail`**

| 字段 | 类型 | 说明 |
|---|---|---|
| `taskId` | string | — |
| `title` | string | — |
| `projectId` / `projectName` | string | 所属项目 |
| `assigner` | object | **分配人/创建人**（含 `uid`、`name`、`finished`）|
| `participants[]` | object | 执行人列表（**含 `uid`、`name`、`finished:bool`**），渲染进度用 |
| `followers[]` | object | 关注人列表（含 `uid`、`name`） |
| `priority` | int | 同上 |
| `deadline` / `deadlineFormat` / `startTime` | int64/int | 时间字段（TaskVo: **毫秒**） |
| `remark` | string | 备注 |
| `rrule` | string | 循环 |
| `alarm` | object | 提醒 |
| `attachments[]` | object | 附件清单（`type`/`name`/`url`/`docUrl` 等，详见 `task_attachment_add` 字段表） |
| `subTasks[]` | object | 子任务列表（`taskId`/`title`/`assignees`/`deadline`/`finished` 等） |
| `commentCount` | int | 评论数（用于详情底部计数渲染） |
| `logCount` | int | 日志数 |
| `createTime` | int64 | 创建时间（TaskVo.taskCreateTime: **毫秒**） |

> 渲染规范见 `task-detail-render.md`。

---

## 8. `task_list` — 任务列表（浏览，四大快捷方式 + 项目内）

> 路径 `/task/list`。**纯浏览**接口，**不做**关键词搜索（关键词请用 [§8b `task_search`](#8b-task_search--关键词搜索任务)）。
> contract v2.0.0：入参**无 `keyword`**，新增 `navigatorId`；回包由 `FlowPage_AgentQueryTaskItem` 改为 `McpTaskListPage`。

**入参 `McpTaskListForm`**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `projectId` | int64 | ❌ | 限定项目 ID；不传 = 全部项目 |
| `navigatorId` | string | ❌ | 导航（快捷方式）枚举，见下表。服务端用当前用户翻译为筛选条件，**skill 无需再拼 uid** |
| `quickConditions` | string[] | ❌ | 快捷筛选枚举（见下表），多值 **AND** |
| `conditions` | object[] | ❌ | 自定义筛选（见下表），多 field 之间 **AND**，同 field 的 `values` 之间 **OR** |
| `pageSize` | int | ❌ | 默认 20，最大 50 |
| `pageToken` | string | ❌ | 续拉游标；回传上次返回的 **`nextPageToken`**（=本页最后一条 taskId） |

**`navigatorId` 枚举（对齐客户端左侧四大快捷方式）**

| 值 | 语义 | 服务端翻译 |
|---|---|---|
| `all` | 全部任务（默认） | 不追加人员条件 |
| `assignee` | 分配给我 | assignee = 当前用户 |
| `follower` | 我关注的 | follower = 当前用户 |
| `creator` | 我创建的 | assigner = 当前用户 |

> 🔑 `navigatorId` 与 `projectId` 可叠加（如"某项目下我创建的"= `projectId` + `navigatorId=creator`）；与 `quickConditions` / `conditions` 也可叠加（AND）。

**`quickConditions` 枚举（contract 共 5 项）**

| 值 | 语义 | 暴露策略 |
|---|---|---|
| `assign_to_me` | 分配给我 | ✅ PRD 暴露 |
| `today_deadline` | 今天截止 | ✅ PRD 暴露 |
| `this_week_deadline` | 本周截止 | ✅ PRD 暴露 |
| `finished` | 已完成 | ✅ PRD 暴露（默认不带，用户主动说"已完成"才用） |
| `unfinished` | 未完成 | ⚠️ **内部用**，作为"默认不展示已完成"实现细节，**不**主动暴露给用户语义入口 |

**`conditions[]` 单元结构**：`{ field: <enum>, values: [...] }`

**`conditions.field` 枚举（contract 共 10 项）**

| field | 语义 | values 期望 | 暴露策略 |
|---|---|---|---|
| `assignee` | 执行人（**责任人**，多值 OR） | uid[] | ✅ PRD 暴露 |
| `assigner` | **分配人/创建人**（单值） | [uid] | ⚠️ 高级，"我创建的"优先用 `navigatorId=creator` |
| `follower` | 关注人 | uid[] | ⚠️ 高级，"我关注的"优先用 `navigatorId=follower` |
| `deadline` | 截止时间 | 时间枚举（`expired` / `before-today` / `today` / `tomorrow` / `future_7_days` / `future` / `next-week` / `this-week` / `next-month` / `not-set`） | ✅ PRD 暴露 |
| `startTime` | 开始时间 | 同上 | ✅ PRD 暴露 |
| `alarmTime` | 提醒时间 | 同上 | ✅ PRD 暴露 |
| `project` | 所属项目 | projectId[] | ✅ PRD 暴露 |
| `priority` | 优先级 | int[]（`1`~`4`） | ✅ PRD 暴露 |
| `createTime` | 创建时间 | 时间枚举 | ⚠️ **高级**，本期不在主流程暴露；用户明确点名时引导其用 `startTime` 或客户端 |
| `finished` | 完成状态 | bool[] | ⚠️ **高级**，语义已被 quickConditions 的 `finished` / `unfinished` 覆盖，不重复暴露 |

> 🔑 **重点区分（contract 已强调，本表二次提示）**：
> - "我创建的" / "我关注的" 优先用 **`navigatorId=creator` / `follower`**（服务端按当前用户翻译，无需拿 uid）；`conditions.assigner` / `follower` 仅在需要查**指定他人** uid 时用。
> - `assigner` = **分配人/创建人**（单值 uid）
> - `assignee` = **责任人/执行人**（多值 uid 数组，列表项里是 `assignees[]`）
> - Agent 端"按执行人分组"必须用 `McpTaskItem.assignees` 展开，**不**得用 `assigner`。

**返回 `McpTaskListPage`**

| 字段 | 类型 | 说明 |
|---|---|---|
| `list[]` | McpTaskItem | 任务项（含**嵌套 `subTasks` 子任务树**，无需本地按 parentId 重组） |
| `hasMore` | bool | 是否还有下一页 |
| `nextPageToken` | string | 下一页 token（=**本页最后一条 taskId 字符串**），无更多时为空串；翻页时作为 `pageToken` 回传 |
| `finishedTaskCount` | int | 已完成任务数 |
| `totalTaskCount` | int | 总任务数（含已完成） |

**`McpTaskItem` 字段（来源客户端列表视图 `ListViewTaskItemVo`）**

| 字段 | 类型 | 说明 |
|---|---|---|
| `taskId` | int64 | — |
| `title` | string | — |
| `projectId` / `projectName` | int64/string | — |
| `creator` | string | 创建者 uid（=分配人 uid） |
| `assigner` | McpUserBrief | 分配人（`uid`、`name`） |
| `assignees[]` | McpUserBrief | 执行人列表（`uid`、`name`、`completed:boolean`、`completeTime:int64` **毫秒**），**分组时用此字段** |
| `priority` | int | 优先级 0=无 1=紧急 2=高 3=中 4=低 |
| `deadline` / `startTime` / `createTime` | int64 | 时间字段（McpTaskItem: **毫秒**，= PO 秒值 ×1000） |
| `deadlineFormat` | int | 截止时间格式 0=无 1=仅日期 2=日期+时间 |
| `completed` | int | 0=未完成 1=已完成 |
| `completeTime` | int64 | ⚠️ **任务级恒 null**（`ListViewTaskItemVo` 不返回）；需完成时间取 `assignees[].completeTime` |
| `isParent` / `parentId` | bool/int64 | 父子关系 |
| `subTasks[]` | McpTaskItem | 子任务（**递归嵌套结构**） |
| `rrule` | string | 循环规则 |
| `completeCondition` | string | 完成条件 `all`/`any_one` |

> ⚠️ **单位陷阱**：`McpTaskItem` 时间字段是**毫秒**（与 §8b `task_search` 的 `AgentQueryTaskItem` **秒** 不同）。`completeTime` 任务级恒 null，取执行人维度 `assignees[].completeTime`。

**示例**

> ⛔ **默认隐藏已完成任务**（铁律 6）：以下示例中"全部 / 分配给我 / 我关注的 / 我创建的 / 某项目下"等未提及完成状态的场景，**均必须带 `quickConditions=["unfinished"]`**。仅当用户主动表达完成状态时按三档语义切换：
> - 「看已完成」/「我已经完成的」/「已完成」快捷筛选 → `quickConditions=["finished"]`
> - 「包含已完成任务」/「全部都看（含已完成）」→ `quickConditions` 不含 `finished`/`unfinished`
> - 默认 → `quickConditions=["unfinished"]`

```bash
# 全部任务（默认隐藏已完成）
popo-cli popo task_list navigatorId=all quickConditions="[\"unfinished\"]"

# 分配给我（默认隐藏已完成）
popo-cli popo task_list navigatorId=assignee quickConditions="[\"unfinished\"]"

# 我关注的（默认隐藏已完成）
popo-cli popo task_list navigatorId=follower quickConditions="[\"unfinished\"]"

# 我创建的（默认隐藏已完成）
popo-cli popo task_list navigatorId=creator quickConditions="[\"unfinished\"]"

# 某项目下所有任务（默认隐藏已完成）
popo-cli popo task_list projectId=123456 quickConditions="[\"unfinished\"]"

# 用户主动要看「已完成」（仅已完成）
popo-cli popo task_list navigatorId=assignee quickConditions="[\"finished\"]"

# 用户主动要「全部都看（含已完成）」（不传 finished/unfinished，两者都展示）
popo-cli popo task_list navigatorId=assignee

# 混合：分配给我 + 本周截止 + 默认隐藏已完成（unfinished 与其他值一起放数组）
popo-cli popo task_list navigatorId=assignee quickConditions="[\"unfinished\",\"this_week_deadline\"]"

# 混合：某项目 + 我创建的 + 本周截止 + 默认隐藏已完成
popo-cli popo task_list projectId=123456 navigatorId=creator quickConditions="[\"unfinished\",\"this_week_deadline\"]"

# 续拉（回传上次 nextPageToken，其他参数保持一致）
popo-cli popo task_list navigatorId=all quickConditions="[\"unfinished\"]" pageToken=<上次返回的nextPageToken>
```

> 工作流细节见 `task-list-workflow.md`。

---

## 8b. `task_search` — 关键词搜索任务

> 路径 `/task/search`（contract v2.0.0 新增）。走底层 `agentQueryTask`（ES）。**有关键词/模糊标题匹配需求时用本接口**，纯浏览用 [§8 `task_list`](#8-task_list--任务列表浏览四大快捷方式--项目内)。

**入参 `McpTaskSearchForm`**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `keyword` | string | ✅ | 标题关键词（ES 匹配），**必填** |
| `projectId` | int64 | ❌ | 限定项目 ID；不传 = 全局搜索 |
| `navigatorId` | string | ❌ | 导航枚举 all/assignee/follower/creator，语义同 §8 |
| `quickConditions` | string[] | ❌ | 快捷筛选，枚举与语义同 §8 |
| `conditions` | object[] | ❌ | 自定义筛选，语义同 §8 |
| `querySort` | object | ❌ | 排序 `{field, order}`，`field` 如 `createTime`/`deadline`/`title`，`order`=`asc`/`desc`；默认按创建时间倒序 |
| `pageSize` | int | ❌ | **默认 50（拉满上限）**；服务端默认 20，skill 调 `task_search` 时主动传 50 减少分页次数（见 [`task-list-workflow.md §8.2`](./task-list-workflow.md#82-task_search-分页-自动续拉兜底--本地相关度重排)） |
| `pageToken` | string | ❌ | 续拉游标；回传上次返回的 **`scrollId`**（首次不传） |

> 条件可叠加：`keyword` + `navigatorId` + `quickConditions` + `conditions` + `querySort` 之间 **AND**。

**返回 `FlowPage_AgentQueryTaskItem`**

| 字段 | 类型 | 说明 |
|---|---|---|
| `list[]` | AgentQueryTaskItem | 任务项（**扁平**结构，父子靠 `parentId`，需本地重组树） |
| `list[].assignees[]` | object | 执行人（`uid`、`name`、`completed:boolean`、`completeTime:int64` **秒**） |
| `list[].deadline` / `startTime` / `createTime` | int64 | 时间字段（AgentQueryTaskItem: **秒**） |
| `list[].completeTime` | int64 | 完成时间（**毫秒**） |
| `list[].priority` / `deadlineFormat` / `rrule` / `completeCondition` | — | 同 §8 语义 |
| `more` / `hasMore` | bool | 是否还有下一页 |
| `scrollId` | string | 滚动游标；翻页时作为 `pageToken` 回传 |

> ⚠️ **分页字段差异**：`task_search` 用 **`scrollId`**（不是 `task_list` 的 `nextPageToken`）。翻页时把上次返回的 `scrollId` 作为下次 `pageToken` 传回。
> ⚠️ **单位差异**：`AgentQueryTaskItem` 的 `deadline`/`startTime`/`createTime` 是**秒**（与 §8 `McpTaskItem` **毫秒** 不同）。
> ⛔ **自动续拉兜底（必读 [`task-list-workflow.md §8.2`](./task-list-workflow.md#82-task_search-分页-自动续拉兜底--本地相关度重排)）**：服务端 ES `match` 查询分词 OR 匹配 + 按 `todoCreateTime DESC` 排序（非相关度），首页结果易全是"部分匹配但更新"的任务。skill **必须**：(1) 主动传 `pageSize=50` 拉满；(2) 首页无完整 token 命中时自动用 `scrollId` 续拉（上限 3 页/150 条）；(3) 本地按 token 命中数重排（完整匹配置顶，部分匹配在后）。3 页拉完仍无完整匹配时停止自动续拉转手动，并明示"未找到完整匹配，以下为部分关键词匹配结果"。

**示例**

> ⛔ **默认隐藏已完成任务**（铁律 6）：`task_search` 同样遵循三档语义，未提及完成状态时**必须**带 `quickConditions=["unfinished"]`。

```bash
# 全局关键词搜索（默认隐藏已完成，pageSize=50 拉满）
popo-cli popo task_search keyword=周报 quickConditions="[\"unfinished\"]" pageSize=50

# 项目内关键词搜索（默认隐藏已完成，pageSize=50 拉满）
popo-cli popo task_search keyword=上线 projectId=123456 quickConditions="[\"unfinished\"]" pageSize=50

# 用户主动要搜「已完成」（仅已完成，pageSize=50 拉满）
popo-cli popo task_search keyword=周报 navigatorId=assignee quickConditions="[\"finished\"]" pageSize=50

# 用户主动要「包含已完成」（两者都展示，不传 finished/unfinished，pageSize=50 拉满）
popo-cli popo task_search keyword=周报 navigatorId=assignee pageSize=50

# 叠加：关键词 + 分配给我 + 默认隐藏已完成 + 按截止时间升序 + pageSize=50 拉满
popo-cli popo task_search keyword=需求评审 navigatorId=assignee \
  quickConditions="[\"unfinished\"]" \
  querySort="{\"field\":\"deadline\",\"order\":\"asc\"}" pageSize=50

# 续拉（回传上次 scrollId，其他参数保持一致，pageSize=50 保持一致）
popo-cli popo task_search keyword=周报 quickConditions="[\"unfinished\"]" pageSize=50 pageToken=<上次返回的scrollId>
```

> **接口路由规则**：有关键词/模糊标题匹配 → `task_search`；纯浏览（四大快捷方式或某项目全部任务）→ `task_list`。

---

## 9. `task_comment_list` — 评论只读

**入参**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `taskId` | int64 | ✅ | — |
| `pageSize` | int | ❌ | 默认 20 |
| `pageToken` | string | ❌ | 续拉，格式 `"scrollId:direction"`，首次不传 |

**返回 `FlowPage_EditRecord`（`list` 中为 `EditRecord`，`eventType` = 19 或 20）**

| 字段 | 类型 | 说明 |
|---|---|---|
| `list[].operatorName` | string | 评论人显示名 |
| `list[].timestamp` | int64 | 评论/操作时刻（EditRecord: **毫秒**） |
| `list[].eventType` | int | `19`=普通评论, `20`=已删除评论 |
| `list[].eventDetail.content` | string | 评论内容（POPO标签格式） |
| `list[].eventDetail.commentId` | int64 | 评论 ID |
| `list[].eventDetail.replyToCommentId` | int64 \| 0 | 非 0 = 回复型评论 |
| `list[].eventDetail.replyToCommentCreatorName` | string | 被回复者昵称（仅回复型） |
| `list[].aiOperated` | bool | 评论场景**恒 false**（MCP 不开放写评论接口），渲染时不加 ✦ 标识 |
| `more` / `hasMore` / `pageToken` | — | 翻页 |

> ⚠️ 对比旧版变更：`replyToScrollId` → `eventDetail.replyToCommentId`、`replyToOperatorName` → `eventDetail.replyToCommentCreatorName`、`content` → `eventDetail.content`。不再使用顶层的 `replyToScrollId` / `replyToOperatorName` / `scrollId` / `action`。`aiOperated` 字段保留（评论场景恒 false）。
>
> 渲染规则（普通 / 回复型 / 已删除 / POPO标签解析）见 `task-comment-log-view.md`。**本期不支持写评论**。

---

## 10. `task_log_list` — 日志只读

**入参**：`taskId`（int64，必填）+ `pageSize` / `pageToken`（同 §9）。

**返回 `FlowPage_EditRecord`（`list` 中为 `EditRecord`，`eventType` 为 1-99 中除 19/20 外的值）**

| 字段 | 类型 | 说明 |
|---|---|---|
| `list[].operatorName` | string | 操作人显示名 |
| `list[].timestamp` | int64 | 操作时刻（EditRecord: **毫秒**） |
| `list[].eventType` | int | 事件类型，见下表 |
| `list[].eventDetail` | object | 事件详情（字段按 eventType 不同使用不同子集） |
| `list[].aiOperated` | bool | 是否 AI 助手（MCP 入口 `/v1/mcp/task/**`）触发产生；`true` 时日志渲染须在操作时间后加 ✦ 标识（见 `task-comment-log-view.md` §2.4） |

**`eventDetail` 字段（按 eventType 取值）**

| 字段 | 类型 | 使用场景（eventType） |
|---|---|---|
| `newTitle` / `prevTitle` | string | 2 |
| `newDeadline` / `prevDeadline` | int64 | 8,9,10 |
| `newDeadlineFormat` / `prevDeadlineFormat` | int | 8,9,10 |
| `newStartTime` / `prevStartTime` | int64 | 32,33,34 |
| `newStartTimeFormat` / `prevStartTimeFormat` | int | 32,33,34 |
| `participants` | `[{name,uid,avatarUrl}]` | 3,4,35,36,37,38,42 |
| `name` | string | 31 |
| `newCompleteCondition` | string (`"all"`\|`"any_one"`) | 39 |
| `prevCompleteCondition` | string | 39 |
| `newFinishPercent` | float (0-1) | 17,40,41 |
| `projectName` | string | 51,52 |
| `newRrule` / `prevRrule` | string | rrule 变更时 |
| `newRemark` / `prevRemark` | string | 备注变更时 |
| `newPriority` / `prevPriority` | int | 优先级变更时 |
| `more` / `hasMore` / `pageToken` | — | 翻页 |

> ⚠️ 对比旧版变更：不再有顶层 `action` 字段；改为按 `eventType` 枚举 + `eventDetail` 子字段拼接展示文案，完整枚举表与渲染规则见 `task-comment-log-view.md` §2。`aiOperated` 字段**保留**（contract `EditRecord.aiOperated:bool`），`true` 时日志渲染加 ✦ 标识。

---

## 11. `task_attachment_add` — 附件登记（写操作 ⛔）

**入参**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `taskId` | string | ✅ | 目标任务 |
| `attachments[]` | object | ✅ | 附件清单（一次可多条） |

**`McpAttachmentForm` 字段表（按 `type` 区分必填）**

| 字段 | 类型 | type=1 图片 | type=2 文件 | type=3 云空间 |
|---|---|:---:|:---:|:---:|
| `type` | int | `1` | `2` | `3` |
| `name` | string | ✅ | ✅ | ❌ |
| `size` | int64 | ✅ | ✅ | ❌ |
| `url` | string | ✅ FP url | ⚠️ **必须 `""` 空字符串** | ⚠️ 必须 `""` |
| `format` | string | ❌ | ✅ 扩展名（不含点） | ❌ |
| `md5` | string | ❌ | ✅ Step 1 的 `fhash` | ❌ |
| `fileId` | string | ❌ | ✅ Step 4 返回的 `ufid` | ❌ |
| `infoType` | int | ❌ | ✅ 固定 `3` | ❌ |
| `objectKey` | string | ❌ | ✅ Step 2 返回的 `objectKey` | ❌ |
| `docId` | string | ❌ | ❌ | ✅ 云空间文档 ID |
| `docUrl` | string | ❌ | ❌ | ✅ 云空间文档 URL |
| `docOwnerUid` | string | ❌ | ❌ | ❌（推荐传，便于权限识别） |
| `docCategory` | int | ❌ | ❌ | ❌（推荐传） |

> 上传链路（type=1 FP / type=2 S3 / type=3 跳过上传）的完整步骤见
> [`task-attachment-upload-workflow.md`](./task-attachment-upload-workflow.md)。

**示例**

```bash
# 图片
popo-cli popo task_attachment_add taskId=t_12345 \
  attachments="[{\"type\":1,\"url\":\"<fp-url>\",\"name\":\"a.png\",\"size\":253247}]"

# 文件
popo-cli popo task_attachment_add taskId=t_12345 \
  attachments="[{\"type\":2,\"url\":\"\",\"name\":\"report.pdf\",\"size\":1048576,\"format\":\"pdf\",\"md5\":\"<fhash>\",\"fileId\":\"<ufid>\",\"infoType\":3,\"objectKey\":\"<objectKey>\"}]"

# 云空间
popo-cli popo task_attachment_add taskId=t_12345 \
  attachments="[{\"type\":3,\"url\":\"\",\"docId\":\"doc_abc\",\"docUrl\":\"https://docs.popo.netease.com/...\"}]"
```

---

## 12. `task_finish` — 完成任务（写操作 ⛔）

> 路径 `/api/inner/ai/v1/task/finish`（contract `task_finish`）。标记整个任务为已完成（未完成→已完成）。对应客户端任务面板"勾选完成"。
> ⚠️ 写操作，**必须二次确认**（铁律 2）。完整工作流见 [`task-create-workflow.md` §4.1](./task-create-workflow.md#41-完成任务task_finish)。

**入参 `McpTaskIdForm`**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `taskId` | int64 | ✅ | 目标任务 ID |

**返回**：`ApiResponse_null`（成功无 body，仅看 HTTP 状态码）。

**调用前必做**：
1. 先 `task_detail taskId=<X>` 拿 title / participants / subTasks / completeCondition
2. 状态预检（已在完成状态 → 不重复调；有未完成执行人/子任务 → 提示用户）
3. 回显摘要 + `ask_user_question` 二次确认（铁律 2）
4. 确认后调 `task_finish taskId=<X>`

```bash
# 完成任务（确认后调用）
popo-cli popo task_finish taskId=t_12345
```

> ⛔ 对多执行人任务：`completeCondition="all"` 要求所有执行人完成才算完成；`"any_one"` 任意一人完成即算完成。finish 是**任务级**操作，标记整个任务完成。

---

## 13. `task_rebuild` — 重开任务（写操作 ⛔）

> 路径 `/api/inner/ai/v1/task/rebuild`（contract `task_rebuild`）。标记已完成任务为未完成（已完成→未完成）。对应客户端"取消勾选完成"。
> ⚠️ 写操作，**必须二次确认**（铁律 2）。完整工作流见 [`task-create-workflow.md` §4.2](./task-create-workflow.md#42-重开任务task_rebuild)。

**入参 `McpTaskIdForm`**

| 字段 | 类型 | 必填 | 说明 |
|---|---|:---:|---|
| `taskId` | int64 | ✅ | 目标任务 ID |

**返回**：`ApiResponse_null`（成功无 body）。

**调用前必做**：
1. 先 `task_detail taskId=<X>` 拿 title / participants
2. 状态预检（当前未完成 → 告知无需重开，不调 rebuild）
3. 回显摘要 + `ask_user_question` 二次确认（铁律 2）
4. 确认后调 `task_rebuild taskId=<X>`

```bash
# 重开任务（确认后调用）
popo-cli popo task_rebuild taskId=t_12345
```

> `task_finish` / `task_rebuild` 互为逆操作，入参结构相同（均 `McpTaskIdForm`），返回均为 null。

---

## 已放开暴露的 tool（原一期未暴露，现已支持）

下列 operationId 原一期未暴露，**现已放开支持**，可正常调用：

| operationId | 用途 | 工作流 |
|---|---|---|
| `task_finish` | 勾选完成任务（未完成→已完成） | [task-create-workflow.md §4.1](./task-create-workflow.md#41-完成任务task_finish) |
| `task_rebuild` | 重开任务（已完成→未完成） | [task-create-workflow.md §4.2](./task-create-workflow.md#42-重开任务task_rebuild) |

> ⚠️ 两者均为写操作，**必须二次确认**（铁律 2）。详见对应工作流。

---

## 字段语义快查（PRD ↔ contract ↔ skill 对照）

| PRD 语义 | List 项字段 | Detail 字段 | `conditions.field` |
|---|---|---|---|
| 执行人 | `McpTaskItem.assignees[]` | `participants[]` | `assignee` |
| 分配人/创建人 | `McpTaskItem.assigner` | `assigner` | `assigner` |
| 关注人 | `McpTaskItem.followers[]` | `followers[]` | `follower` |
| 所属项目 | `McpTaskItem.projectId` | `projectId` | `project` |
| 优先级 | `McpTaskItem.priority` | `priority` | `priority` |
