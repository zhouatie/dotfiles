---
name: popo-calendar
description: "POPO 日历会议一站式管理：预约会议、预订会议室、查看日程、取消/改期会议、查询节假日。触发场景：(1) 预约会议 —\"帮我约个会议\"、\"和张三明天下午开个会\"、\"帮我订一个会议室\"，以及任何涉及创建/预约/安排会议的请求；(2) 查看日程 —\"我明天有什么安排\"、\"查一下张三周五的日程\"、\"张三明天有空吗\"；(3) 管理会议 —\"取消今天下午的会议\"、\"把会议改到明天\"、\"加王五到会议里\"；(4) 节假日查询 —\"五一放几天假\"、\"查一下端午节日期\"；(5) 隐式触发 — 当用户表达\"碰一下/见个面/聊聊/谈一下/开个会\"等社交意图并伴随时间意图时，自动触发预约会议流程。即使用户没有明确说\"约会议\"或\"查日程\"，只要意图涉及日历、会议、日程、会议室的操作，都应使用此skill。注意：此skill的用户搜索（popo_calendar_user_search）仅作为日历操作的前置步骤，不用于独立的员工信息查询（独立查询请使用popo-im skill）。"
---

# POPO Calendar Skill

所有操作通过 Bash 执行 `popo-cli <工具名> key=value` 命令完成。

> **参数值引号规则（跨平台兼容，禁止使用单引号）**
>
> 为确保命令在 bash、CMD、PowerShell 等不同 shell 下均能正确执行，统一使用**双引号**作为引用符：
> - 简单值（无空格、无特殊字符）**不加引号**：`key=value`
> - 含空格或特殊字符的值用**双引号**包裹：`key="value with spaces"`
> - JSON 数组/对象用**双引号**包裹，内部双引号使用 `\"` 转义：`key="[\"a\",\"b\"]"`
>
> ```bash
> # ✅ 简单值 — 不需要引号
> popo-cli popo calendar_user_search keyword=张三
>
> # ✅ 含空格 — 双引号包裹
> popo-cli popo calendar_schedule_create title="项目进度 Review" startTime=2026-04-22T14:00:00+08:00
>
> # ✅ 数组参数 — 双引号包裹 + 内部 \" 转义
> popo-cli popo calendar_freebusy uids="[\"a@corp.com\",\"b@corp.com\"]" startTime=2026-04-22T09:00:00+08:00 endTime=2026-04-22T18:00:00+08:00
>
> # ❌ 错误 — 空格导致参数断裂
> popo-cli popo calendar_schedule_create title=项目进度 Review
>
> # ❌ 错误 — 使用单引号（Windows CMD 不支持）
> popo-cli popo calendar_freebusy uids='["a@corp.com","b@corp.com"]'
> ```

> **兜底：HTTP 直传调用**
> 当 `popo-cli <工具名> key=value` 调用后服务端返回类型解析错误（如 `Cannot construct instance of java.util.ArrayList`、`JSON parse error` 等），说明参数中的数组/对象值未被正确序列化。此时改用 HTTP 直传方式重试，手动构造合法 JSON 以保证类型正确：
> ```
> popo-cli call POST /api/v1/open-apis/gateway/appcode/popo/_invoke --body "{\"tool\":\"<工具名>\",\"params\":{...}}"
> ```
> 示例：
> ```bash
> popo-cli call POST /api/v1/open-apis/gateway/appcode/popo/_invoke --body "{\"tool\":\"popo_calendar_freebusy\",\"params\":{\"uids\":[\"a@corp.com\",\"b@corp.com\"],\"startTime\":\"2026-04-22T09:00:00+08:00\",\"endTime\":\"2026-04-22T18:00:00+08:00\"}}"
> ```

---

## ⛔ 六条铁律（每次操作前必须检查）

**铁律 1：所有调用的 popo-cli 命令，必须到[./references/tool-reference.md](./references/tool-reference.md)中查询相应工具的参数说明，不得随意捏造**

**铁律 2：查别人日程必须传 `targetUid`**
- 用户说"查张三的日程" → 先 `popo_calendar_user_search` 获取张三 uid → 再 `popo_calendar_schedule_list` 传 `targetUid`
- 用户说"查看**我的**日程"时，不需要传递 `targetUid`，默认会查自己的

**铁律 3：预约/取消前必须先展示信息让用户确认，信息要带出来参会人的邮箱，用户说"确认"后才能执行 `popo_calendar_schedule_create` / `popo_calendar_schedule_cancel`**
- 禁止跳过确认直接创建或取消，禁止带出locationId等信息给到用户

**铁律 4：预约会议优先搜索会议室**
- 除非用户明确说"不要会议室"，否则先调用 `popo_calendar_room_search` 搜索会议室并带入创建参数，搜索时传递的时间范围不要太大
- 搜不到可用会议室时仍继续创建会议，但需告知用户

**铁律 5：popo_calendar_user_search 多匹配处理**
- 姓名或昵称与 keyword **完全匹配** → 直接选完全匹配的，无需用户确认
- 无完全匹配 → 展示候选列表让用户选择
- 零匹配 → 告知用户未找到，建议换关键字

**铁律 6：约会议，查忙闲时，先要调用popo_calendar_user_info查询当前用户，查忙闲要考虑当前用户的忙闲状态**

**铁律 7：不支持群、组织、部门维度的会议预约和修改，当用户的意图涉及到群、部门和组织时，直接告诉用户，当前我还不支持～**

---

## NEVER DO

- 一定不要直接创建、取消、退出会议，需要用户确认后才允许执行popo_calendar_schedule_create，popo_calendar_schedule_cancel，popo_calendar_schedule_quit
- 查询用户邮箱、查询location等过程信息，不要输出给用户！
- 不要猜测 `scheduleId` / `meetingRoomId` / `uid` 等 ID，必须从接口获取
- 不要使用 curl / python，统一使用 `popo-cli` 命令
- 时间参数统一 **ISO-8601**（如 `2026-03-25T14:00:00+08:00`），不要传时间戳
- 姓名/昵称必须先 `popo_calendar_user_search` 查邮箱，不要猜测邮箱
- `popo_calendar_user_search` 多匹配且无完全匹配时，展示候选让用户选；零匹配时告知用户并停止
- 判断是否为循环日程**必须基于 `recurrence` 字段**（`popo_calendar_schedule_list` 和 `popo_calendar_schedule_detail` 返回值中均包含），`recurrence=1` 为循环日程，`recurrence=0` 为非循环日程
- 循环日程取消必须询问范围（仅本次/本次及以后/全部）并传 `cancelType`
- 循环日程确认（接受/拒绝）必须先询问操作范围（仅本次/本次及以后/全部）并传 `type`，**禁止默认操作全部**
- 循环日程退出必须先询问退出范围（仅本次/本次及以后/全部）并传 `type`，**禁止默认操作全部**
- 取消前必须判断当前用户是否为会议创建者
- popo_calendar_user_search工具，只能传入具体的姓名或者昵称，我、你、他这种字眼，不允许查询。

---

## 模糊时间映射（严格遵守）如果用户空闲时间不够默认时长，按空闲时间预定

| 用户表述 | 查询范围 |  默认时长  |
|---------|---------|:------:|
| "上午" | 09:30 - 12:00 |  1小时   |
| "下午" | 13:30 - 18:30 |  1小时   |
| "晚上" | 19:30 - 21:00 |  1小时   |
| "明天"（无上下午） | 09:30-12:00、14:00-18:30、19:30-21:00 |  1小时   |
| "全天" | 09:30 - 21:00 | 11.5小时 |
| "x点" | 直接使用 |  1小时   |
| "x点到y点" | 用户指定 |   —    |

> **⚠️ "全天"预约会议约束**：用户在预约会议时说到"全天"，必须将会议时间固定设置为 **09:30 - 21:00**，不得询问用户具体时间。

---

## 工具速查

| 操作         | tool                        | 参考 |
|------------|-----------------------------|------|
| 用户搜索       | `popo_calendar_user_search`      | [详情](./references/tool-reference.md#popo_calendar_user_search) |
| 忙闲查询       | `popo_calendar_freebusy`         | [详情](./references/tool-reference.md#popo_calendar_freebusy) |
| 节假日查询      | `popo_calendar_holiday_freebusy` | [详情](./references/tool-reference.md#popo_calendar_holiday_freebusy) |
| 会议室搜索      | `popo_calendar_room_search`      | [详情](./references/tool-reference.md#popo_calendar_room_search) |
| 日程详情       | `popo_calendar_schedule_detail`  | [详情](./references/tool-reference.md#popo_calendar_schedule_detail) |
| 创建日程       | `popo_calendar_schedule_create`  | [详情](./references/tool-reference.md#popo_calendar_schedule_create) |
| 日程列表       | `popo_calendar_schedule_list`    | [详情](./references/tool-reference.md#popo_calendar_schedule_list) |
| 更新日程       | `popo_calendar_schedule_update`  | [详情](./references/tool-reference.md#popo_calendar_schedule_update) |
| 取消日程       | `popo_calendar_schedule_cancel`  | [详情](./references/tool-reference.md#popo_calendar_schedule_cancel) |
| 确认日程（接受/拒绝） | `popo_calendar_schedule_confirm` | [详情](./references/tool-reference.md#popo_calendar_schedule_confirm) |
| 退出日程       | `popo_calendar_schedule_quit`    | [详情](./references/tool-reference.md#popo_calendar_schedule_quit) |
| location查询 | `popo_calendar_location_search`  | [详情](./references/tool-reference.md#popo_calendar_location_search) |
| 当前用户       | `popo_calendar_user_info`  | [详情](./references/tool-reference.md#popo_calendar_user_info) |

关键区分：
- `popo_calendar_freebusy`（忙闲查询）返回忙碌时段，用于排会议找空闲
- `popo_calendar_schedule_list`（日程列表）返回具体日程条目，用于查看/定位会议
- `popo_calendar_room_search` 不传 locationId/capacity 走智能推荐，传了走条件搜索
- 更新参与人/会议室用增量 add/remove，先查 `popo_calendar_schedule_detail` 再决定增减

---

## 工作流 1：预约会议

### 必须信息 vs 自动推断

| 信息 | 必须？ | 处理 |
|-----|:---:|:---|
| 参与人 | ✅ | 缺则追问 |
| 时间意图 | ✅ | 缺则追问 |
| 会议时长 | ❌ | 默认 1 小时 |
| 具体时间段 | ❌ | 查忙闲自动选空闲 |
| 会议室 | ❌ | **默认搜索并预订**（铁律 4） |
| 标题 | ❌ | 自动生成："参与人A、参与人B 会议" |

> 隐式触发：用户说"碰一下/见个面/聊聊/谈一下/开个会"+ 时间意图 → 触发预约流程

### 执行步骤

```
Step 1  解析参与人
        popo_calendar_user_search → 获取 uid
        ├─ 唯一匹配 → 继续
        ├─ 多匹配且完全匹配 → 选完全匹配的
        ├─ 多匹配无完全匹配 → 展示候选让用户选
        └─ 零匹配 → 告知用户，停止
        
Step 2  获取当前用户
        popo_calendar_user_info → 获取当前用户 uid

Step 3  查忙闲（需要传递Step 1、2的所有uid）
        popo_calendar_freebusy
        ├─ 有共同空闲 → 列出空闲时段供选择
        ├─ 部分冲突 → 告知冲突，询问是否强制
        └─ 完全无空闲 → 告知，请用户调整

Step 4  搜索会议室（铁律 3，不可跳过）
        如果用户明确说了地点 → 先根据popo_calendar_location_search查到最匹配用户输入的园区id，在调用popo_calendar_room_search，传入园区id
        时间范围不能太大，否则可能会搜不到空闲的会议室，一般范围控制在1个小时内
        popo_calendar_room_search → 推荐第一个 bookFlag=1 的会议室
        └─ 无可用 → 标记无会议室，继续

Step 5  展示确认信息，等待用户确认（铁律 3，不可跳过）
        展示：时间、参与人、会议室、标题
        ├─ 用户说"确认" → Step 5
        ├─ 用户要调整 → 回到对应步骤
        └─ 用户说"取消" → 停止

Step 6  创建会议
        用户确认后，执行popo_calendar_schedule_create（含 meetingRoomIds）
        → 检查 failedMeetingRoomIds，告知结果
```

### API 示例

```
# Step 1
popo-cli popo calendar_user_search keyword=张三

# Step 2
popo-cli popo calendar_user_info

# Step 3（必须包含step1和2的操作者 uid）
popo-cli popo calendar_freebusy uids="[\"operator@corp.com\",\"zhangsan@corp.com\"]" startTime=2026-04-02T13:30:00+08:00 endTime=2026-04-02T18:30:00+08:00

# Step 4（不可跳过）
# 如果用户明确指示了地点信息，先通过popo_calendar_location_search工具查到园区name——>id的map，获取到最匹配的园区id，在调用popo_calendar_room_search，传入园区id
popo-cli popo calendar_room_search startTime=2026-04-02T14:00:00+08:00 endTime=2026-04-02T15:00:00+08:00 locationId=园区id

# Step 5：展示信息，等用户确认

# Step 6（用户确认后才执行）
popo-cli popo calendar_schedule_create title="张三 会议" startTime=2026-04-02T14:00:00+08:00 endTime=2026-04-02T15:00:00+08:00 participants="[\"zhangsan@corp.com\"]" meetingRoomIds="[\"room-001\"]" content=会议备注信息
```

---

## 工作流 2：预订会议室（无会议）

只需时间意图，缺则追问。不传 capacity/location 走智能推荐。

```
Step 1  映射时间
Step 2  popo_calendar_room_search → 推荐前 5 个
Step 3  展示确认，等用户确认（铁律 3）
Step 4  用户确认后，popo_calendar_schedule_create（仅含 meetingRoomIds，无 participants）
```

---

## 工作流 3：查看日程

### ⚠️ 查自己 vs 查别人（铁律 2）

| 场景 | 调用方式                                                                                                                                                   |
|------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| "查看**我**明天的日程" | `popo_calendar_schedule_list({"date": "2026-04-02"})`                                                            |
| "**张三**周五有安排吗" | 先 `popo_calendar_user_search({"keyword": "张三"})` → 再 `popo_calendar_schedule_list({"targetUid": "zhangsan@corp.com", "date": "2026-04-04"})` — **必须传** targetUid |
| "**张三**明天有空吗" | 先查 uid → `popo_calendar_freebusy({"uids": ["zhangsan@corp.com"], ...})` |

---

## 工作流 4：取消会议

```
Step 1  popo_calendar_schedule_list → 定位目标会议
Step 2  popo_calendar_schedule_detail → 确认详情
Step 3  判断是否为创建者 → 非创建者则告知并停止
Step 4  循环日程 → 询问取消范围（cancelType: 1=本次, 2=此后, 0=全部）
Step 5  展示确认，等用户说"确认取消"（铁律 2）
Step 6  popo_calendar_schedule_cancel
```

---

## 工作流 5：改期会议

```
Step 1  popo_calendar_schedule_list → 定位会议
Step 2  popo_calendar_schedule_detail → 获取参与人
Step 3  popo_calendar_freebusy → 查新时间忙闲（含操作者）
Step 4  popo_calendar_schedule_update（若需换会议室先 room_search）
```

---

## 工作流 6：确认日程邀请（接受/拒绝）

```
Step 1  popo_calendar_schedule_list → 定位目标日程
Step 2  popo_calendar_schedule_detail → 确认日程详情
Step 3  展示日程信息，确认用户意图（接受/拒绝）
Step 4  ⚠️ 判断是否为循环日程（基于返回值中的 `recurrence` 字段：1=循环，0=非循环）
        ├─ 循环日程（recurrence=1） → **必须主动询问用户操作范围**：
        │   "这是一个循环日程，请选择操作范围：1️⃣ 仅本次  2️⃣ 本次及以后  3️⃣ 全部"
        │   用户选择后传对应 type（1/2/3）及 date（yyyyMMdd）
        └─ 非循环日程（recurrence=0） → type 不传或传 3
Step 5  用户确认后，执行 popo_calendar_schedule_confirm
        ├─ status=1 → 接受
        └─ status=2 → 拒绝
```

### API 示例

```bash
# 接受一个普通日程
popo-cli popo calendar_schedule_confirm scheduleId=123456789 status=1

# 拒绝一个普通日程
popo-cli popo calendar_schedule_confirm scheduleId=123456789 status=2

# 接受循环日程的某一次
popo-cli popo calendar_schedule_confirm scheduleId=123456789 status=1 type=1 date=20260501

# 拒绝循环日程本次及以后
popo-cli popo calendar_schedule_confirm scheduleId=123456789 status=2 type=2 date=20260501
```

---

## 工作流 7：退出日程

```
Step 1  popo_calendar_schedule_list → 定位目标日程
Step 2  popo_calendar_schedule_detail → 确认日程详情，判断当前用户是否为参与人（非创建者）
        ├─ 当前用户是创建者 → 告知用户应使用「取消日程」而非「退出日程」，停止
        └─ 当前用户是参与人 → 继续
Step 3  ⚠️ 判断是否为循环日程（基于返回值中的 `recurrence` 字段：1=循环，0=非循环）
        ├─ 循环日程（recurrence=1） → **必须主动询问用户退出范围**：
        │   "这是一个循环日程，请选择退出范围：1️⃣ 仅本次  2️⃣ 本次及以后  3️⃣ 全部"
        │   用户选择后传对应 type（1/2/3）及 date（yyyyMMdd）
        └─ 非循环日程（recurrence=0） → type 不传或传 3
Step 4  展示确认信息，等用户说"确认退出"
Step 5  用户确认后，执行 popo_calendar_schedule_quit
```

### API 示例

```bash
# 退出一个普通日程
popo-cli popo calendar_schedule_quit scheduleId=123456789

# 退出循环日程的某一次
popo-cli popo calendar_schedule_quit scheduleId=123456789 type=1 date=20260501

# 退出循环日程本次及以后
popo-cli popo calendar_schedule_quit scheduleId=123456789 type=2 date=20260501
```

---

## 工作流 8：查询节假日

```
popo-cli popo calendar_holiday_freebusy beginDate=2026-05-01 endDate=2026-05-05 areas="[\"China\"]"
```

---

## 上下文传递

| 操作 | 提取 | 用于 |
|------|------|------|
| `popo_calendar_user_search` | `uid` | 所有需要用户 uid 的操作 |
| `popo_calendar_schedule_list` | `id` | detail / update / cancel |
| `popo_calendar_schedule_detail` | `participants`, `locations` | update 的增减决策 |
| `popo_calendar_room_search` | `meetingRoomId`(bookFlag=1) | create / update |
| `popo_calendar_freebusy` | 空闲时段 | 选择会议时间 |
| `popo_calendar_schedule_create` | `scheduleId`, `failedMeetingRoomIds` | 后续操作 |
| `popo_calendar_schedule_confirm` | `id` | 确认结果 |

## 错误处理

- `popo-cli` 命令报错时查看错误信息，报告给用户
- 认证失败(401/403) → 检查环境变量 `uid`
- 禁止自行尝试替代方案

## 详细参考

- [references/tool-reference.md](./references/tool-reference.md) — 全部工具参数与返回值
