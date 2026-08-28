# POPO 日历工具参考

所有操作通过 Bash 执行 `popo-cli <工具名> key=value` 命令完成。

## 时间格式

**所有时间参数使用 ISO-8601 格式（如 `2026-03-25T14:00:00+08:00`），必须包含时区偏移。**

| tool | 字段 | 格式 |
|------|------|------|
| `popo_calendar_freebusy` (请求) | `startTime` / `endTime` | **ISO-8601** |
| `popo_calendar_freebusy` (返回 busyList) | `beginTime` / `endTime` | **ISO-8601** |
| `popo_calendar_holiday_freebusy` | `beginDate` / `endDate` | 日期字符串 `yyyy-MM-dd` |
| `popo_calendar_room_search` | `startTime` / `endTime` | **ISO-8601** |
| `popo_calendar_schedule_create` | `startTime` / `endTime` | **ISO-8601** |
| `popo_calendar_schedule_list` | `beginTime` / `endTime` | **ISO-8601** |
| `popo_calendar_schedule_list` | `date` | 日期字符串 `yyyy-MM-dd` |
| `popo_calendar_schedule_update` | `startTime` / `endTime` / `updateStartTime` | **ISO-8601** |
| `popo_calendar_schedule_cancel` | `date` | **yyyyMMdd** |
| `popo_calendar_schedule_confirm` | `date` | **yyyyMMdd** |
| `popo_calendar_schedule_quit` | `date` | **yyyyMMdd** |


---

## popo_calendar_user_search

根据用户姓名、昵称或邮箱关键字搜索用户，获取用户邮箱（uid）。用于用户提供姓名而非邮箱时，先解析出邮箱再调用其他日历接口。最多返回 10 个匹配用户。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `keyword` | String | 是 | 查询关键字（用户姓名、昵称、邮箱等） |

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `uid` | String | 用户 uid（邮箱），可直接用于其他日历接口的 uid / participants 参数 |
| `name` | String | 真名 |
| `nickname` | String | 昵称 |
| `deptName` | String | 部门信息 |

### 判断逻辑

- **唯一匹配**（`data` 仅 1 条）→ 直接使用该 `uid` 继续后续操作
- **多个匹配**（`data` 多条）→ 如果返回的姓名或者昵称和keyword完全匹配时，直接选完全匹配的，否则将候选列表展示给用户，由用户选择目标用户
- **无匹配**（`data` 为空）→ 告知用户未找到匹配用户，建议换个关键字重试

### 示例

```
popo-cli popo calendar_user_search keyword=张三
```

---

## popo_calendar_schedule_confirm

接受或拒绝日程邀请。代用户对日程邀请进行接受或拒绝操作。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `scheduleId` | Long | 是 | 日程 ID，可通过 `popo_calendar_schedule_list` 或 `popo_calendar_schedule_detail` 获取 |
| `status` | Integer | 是 | 回执状态：`1` = 接受，`2` = 拒绝 |
| `type` | Integer | 否 | 操作范围：`1` = 仅本次，`2` = 本次及以后，`3` = 全部（默认）。**非循环日程固定传 `3` 或不传** |
| `date` | String | 否 | 循环日程的操作基准日期，格式 `yyyyMMdd`（如 `20260501`）。**仅当 `type=1` 或 `type=2` 时有意义**，`type=3` 时忽略。默认当天日期 |
| `timezone` | String | 否 | 时区标识（如 `Asia/Shanghai`），用于 `date` 默认值的计算。默认 `Asia/Shanghai` |

### 参数组合说明

| 场景 | 推荐参数 |
|------|---------|
| 接受一个普通（非循环）日程 | `scheduleId` + `status=1` |
| 拒绝一个普通（非循环）日程 | `scheduleId` + `status=2` |
| 接受循环日程的某一次 | `scheduleId` + `status=1` + `type=1` + `date=20260501` |
| 拒绝循环日程本次及以后 | `scheduleId` + `status=2` + `type=2` + `date=20260501` |
| 接受循环日程全部实例 | `scheduleId` + `status=1`（type 不传，默认全部） |

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | Long | 操作的日程 ID |

### 示例

```
# 接受普通日程
popo-cli popo calendar_schedule_confirm scheduleId=123456789 status=1

# 拒绝普通日程
popo-cli popo calendar_schedule_confirm scheduleId=123456789 status=2

# 接受循环日程的某一次
popo-cli popo calendar_schedule_confirm scheduleId=123456789 status=1 type=1 date=20260501

# 拒绝循环日程本次及以后
popo-cli popo calendar_schedule_confirm scheduleId=123456789 status=2 type=2 date=20260501
```

---

## popo_calendar_schedule_quit

退出日程。代用户主动退出某个日程（参与人退出，**不同于创建人取消日程**）。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `scheduleId` | Long | 是 | 日程 ID，可通过 `popo_calendar_schedule_list` 或 `popo_calendar_schedule_detail` 获取 |
| `type` | Integer | 否 | 退出范围：`1` = 仅本次，`2` = 本次及以后，`3` = 全部（默认）。**非循环日程固定传 `3` 或不传** |
| `date` | String | 否 | 循环日程的操作基准日期，格式 `yyyyMMdd`（如 `20260501`）。**仅当 `type=1` 或 `type=2` 时有意义**，`type=3` 时忽略。默认当天日期 |
| `timezone` | String | 否 | 时区标识（如 `Asia/Shanghai`），用于 `date` 默认值的计算。默认 `Asia/Shanghai` |

### 参数组合说明

| 场景 | 推荐参数 |
|------|---------|
| 退出一个普通（非循环）日程 | `scheduleId`（其余不传） |
| 退出循环日程的某一次 | `scheduleId` + `type=1` + `date=20260501` |
| 退出循环日程本次及以后 | `scheduleId` + `type=2` + `date=20260501` |
| 退出循环日程全部实例 | `scheduleId`（type 不传，默认全部） |

### 返回值

无

### 示例

```
# 退出普通日程
popo-cli popo calendar_schedule_quit scheduleId=123456789

# 退出循环日程的某一次
popo-cli popo calendar_schedule_quit scheduleId=123456789 type=1 date=20260501

# 退出循环日程本次及以后
popo-cli popo calendar_schedule_quit scheduleId=123456789 type=2 date=20260501
```

---

## popo_calendar_freebusy

查询一人或多人在指定时间段的忙碌时段。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `uids` | String[] | 是 | 用户 uid 列表（邮箱格式） |
| `startTime` | String | 是 | 开始时间（ISO-8601） |
| `endTime` | String | 是 | 结束时间（ISO-8601） |
| `timezone` | String | 否 | 时区，默认 Asia/Shanghai |
| `excludeScheduleId` | Integer | 否 | 排除的日程 ID（编辑日程时使用） |

### 返回值

数组，每项包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `uid` | String | 用户 uid |
| `name` | String | 用户姓名 |
| `busyList` | Array | 忙碌时段列表，每项含 `beginTime`(ISO-8601)、`endTime`(ISO-8601)、`title` |

### 示例

```
popo-cli popo calendar_freebusy uids='["zhangsan@corp.com","lisi@corp.com"]' startTime=2026-03-25T09:00:00+08:00 endTime=2026-03-25T18:00:00+08:00
```

---

## popo_calendar_holiday_freebusy

查询指定地区的法定节假日和调休。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `beginDate` | String | 是 | 开始日期（yyyy-MM-dd） |
| `endDate` | String | 是 | 结束日期（yyyy-MM-dd，范围 <= 30 天） |
| `areas` | String[] | 否 | 地区列表，不传返回所有地区 |

可用地区：China, US, UK, HK, Japan, Singapore, France, Korea, Vancouver, Montreal, Toronto, Ireland, Spain, ThunderFire

### 返回值

`Map<String, Array>`，key 为地区名，value 为节假日数组，每项含 `date` 和 `title`。

### 示例

```
popo-cli popo calendar_holiday_freebusy beginDate=2025-05-01 endDate=2025-05-05 areas='["China"]'
```

---

## popo_calendar_room_search

搜索可用会议室。不传 keyword/capacity 走智能推荐（基于 IP 定位园区）。

### 参数

| 参数 | 类型 | 必填 | 说明                           |
|------|------|------|------------------------------|
| `startTime` | String | 是 | 开始时间（ISO-8601）               |
| `endTime` | String | 是 | 结束时间（ISO-8601）               |
| `timezone` | String | 否 | 时区，默认 Asia/Shanghai          |
| `capacity` | Integer | 否 | 最小容纳人数                       |
| `meetingRoomIds` | String[] | 否 | 指定会议室 ID 列表                  |
| `clientIp` | String | 否 | 客户端 IP（用于园区自动定位）             |
| `locationId` | Integer | 否 | 根据popo_calendar_location_search获取 |

### 返回值

分页结构，含 `list[]` 和 `hasMore`。每项关键字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `meetingRoomId` | String | 会议室 ID |
| `name` | String | 会议室名称 |
| `capacity` | Integer | 容纳人数 |
| `bookFlag` | Integer | 1=可预约，0=不可预约 |
| `tagList` | Array | 标签列表 |
| `deviceList` | Array | 设备列表 |

> 创建会议时只使用 `bookFlag=1` 的会议室。

### 示例

```
popo-cli popo calendar_room_search startTime=2026-03-25T14:00:00+08:00 endTime=2026-03-25T15:00:00+08:00 capacity=6
```

如果用户提到了地点，如杭州二园区，则先根据popo_calendar_location_search查到园区name——>id的map，获取到最匹配的园区id。
```
popo-cli popo calendar_location_search
popo-cli popo calendar_room_search startTime=2026-03-25T14:00:00+08:00 endTime=2026-03-25T15:00:00+08:00 locationId=园区id
```

---

## popo_calendar_schedule_detail

获取单个日程/会议的详细信息，包括参与人和会议室。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `scheduleId` | Integer | 是 | 日程 ID |

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | Long | 日程 ID |
| `title` | String | 标题 |
| `content` | String | 描述/备注 |
| `startTime` | String | 开始时间（ISO-8601） |
| `endTime` | String | 结束时间（ISO-8601） |
| `creator` | String | 创建者 |
| `locations` | Array | 地点列表（type 1=自定义地点, 2=会议室） |
| `participants` | Array | 参与人列表，每项含 `uid`、`name` |
| `ownerReceiptConfirm` | Integer | 当前日历本所有者的确认状态（0=未处理，1=接受，2=拒绝） |
| `recurrence` | Integer | 是否循环日程（0=否，1=是） |

### 示例

```
popo-cli popo calendar_schedule_detail scheduleId=123456789
```

---

## popo_calendar_schedule_create

创建日程并可选预约会议室。自动发送邀请通知。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `title` | String | 是 | 会议标题 |
| `startTime` | String | 是 | 开始时间（ISO-8601） |
| `endTime` | String | 是 | 结束时间（ISO-8601） |
| `timezone` | String | 否 | 时区，默认 Asia/Shanghai |
| `participants` | String[] | 否 | 参与人 uid 列表 |
| `meetingRoomIds` | String[] | 否 | 会议室 ID 列表 |
| `location` | String | 否 | 地点文本 |
| `content` | String | 否 | 会议描述/备注 |
| `daylong` | Integer | 否 | 1=全天事件 |
| `cycle` | Integer | 否 | 1=循环日程 |
| `rrule` | String | 否 | iCalendar 循环规则（cycle=1 时必填） |
| `remind` | Integer | 否 | 0=不提醒 |
| `remindMinutes` | Integer[] | 否 | 提醒分钟数列表，如 `[5, 15]` |
| `needVmeeting` | Boolean | 否 | 是否创建视频会议链接 |
| `busy` | Integer | 否 | 1=忙碌(默认), 0=空闲 |

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `scheduleId` | Long | 日程 ID |
| `failedMeetingRoomIds` | String[] | 预约失败的会议室 ID 列表 |

> 检查 `failedMeetingRoomIds`，非空表示部分会议室预约失败。

### 示例

```
popo-cli popo calendar_schedule_create title=技术评审 startTime=2026-03-25T14:00:00+08:00 endTime=2026-03-25T15:00:00+08:00 participants='["zhangsan@corp.com","lisi@corp.com"]' meetingRoomIds='["room-001"]'
```

---

## popo_calendar_schedule_list

查询日程列表。三种使用模式：
- `targetUid` + `date` — 查某人某天的日程
- `meetingRoomId` + `date` — 查会议室占用情况
- `date` 或 `beginTime` + `endTime` — 查自己的日程

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `targetUid` | String | 否 | 目标用户 uid |
| `meetingRoomId` | String | 否 | 目标会议室 ID |
| `date` | String | 与 beginTime/endTime 二选一 | 日期（yyyy-MM-dd），优先于 beginTime/endTime |
| `beginTime` | String | 与 date 二选一 | 开始时间（ISO-8601） |
| `endTime` | String | 与 date 二选一 | 结束时间（ISO-8601） |
| `timezone` | String | 否 | 时区，默认 Asia/Shanghai |
| `keyword` | String | 否 | 标题关键词过滤 |
| `bookIdList` | Integer[] | 否 | 日历本 ID 列表 |

### 返回值

数组，每项包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | Long | 日程 ID |
| `title` | String | 标题 |
| `location` | String | 地点 |
| `startTime` | String | 开始时间（ISO-8601） |
| `endTime` | String | 结束时间（ISO-8601） |
| `daylong` | Boolean | 是否全天 |
| `creator` | String | 创建者 |
| `busy` | Integer | 忙碌状态 |
| `attendStatus` | Integer[] | 表示当前用户对日程的参与状态：0=未响应，1=接受，2=拒绝 |
| `recurrence` | Integer | 是否循环日程（0=否，1=是） |

### 示例

```
popo-cli popo calendar_schedule_list date=2025-03-25

popo-cli popo calendar_schedule_list targetUid=zhangsan@corp.com date=2025-03-25

popo-cli popo calendar_schedule_list beginTime=2026-03-25T00:00:00+08:00 endTime=2026-03-25T23:59:59+08:00
```

---

## popo_calendar_schedule_update

更新日程，仅发送需要修改的字段。参与人/会议室使用增量 add/remove，不是全量替换。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `scheduleId` | Integer | 是 | 日程 ID |
| `title` | String | 否 | 新标题 |
| `startTime` | String | 否 | 新开始时间（ISO-8601） |
| `endTime` | String | 否 | 新结束时间（ISO-8601） |
| `timezone` | String | 否 | 时区 |
| `location` | String | 否 | 新地点 |
| `content` | String | 否 | 新描述/备注 |
| `addParticipants` | String[] | 否 | 要添加的参与人 uid 列表 |
| `removeParticipants` | String[] | 否 | 要移除的参与人 uid 列表 |
| `addMeetingRoomIds` | String[] | 否 | 要添加的会议室 ID 列表 |
| `removeMeetingRoomIds` | String[] | 否 | 要移除的会议室 ID 列表 |
| `updateType` | Integer | 否 | 更新范围：0=全部(默认), 1=仅本次, 2=本次及以后 |
| `updateStartTime` | String | 否 | 循环日程实例开始时间（ISO-8601），updateType 为 1 或 2 时必填 |

> 修改参与人/会议室前，先用 `popo_calendar_schedule_detail` 查当前状态再决定增减。

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `scheduleId` | Long | 日程 ID |
| `success` | Boolean | 是否成功 |

### 示例

```
popo-cli popo calendar_schedule_update scheduleId=123456789 startTime=2026-03-26T14:00:00+08:00 endTime=2026-03-26T15:00:00+08:00

popo-cli popo calendar_schedule_update scheduleId=123456789 addParticipants='["wangwu@corp.com"]' removeParticipants='["lisi@corp.com"]'
```

---

## popo_calendar_schedule_cancel

取消日程并释放会议室资源。

### 参数

| 参数 | 类型 | 必填 | 说明                                                                                          |
|------|------|------|---------------------------------------------------------------------------------------------|
| `scheduleId` | Integer | 是 | 日程 ID                                                                                       |
| `cancelType` | Integer | 否 | 取消范围：0=全部(默认), 1=仅本次, 2=本次及以后                                                               |
| `notifyParticipants` | Boolean | 否 | 是否通知参与人，默认 true                                                                             |
| `date` | String | 否 | 循环日程的操作基准日期，格式 `yyyyMMdd`（如 `20260501`）。**仅当 `type=1` 或 `type=2` 时有意义**，`type=0` 时忽略。默认当天日期 |
| `timezone` | String | 否 | 时区标识（如 `Asia/Shanghai`），用于 `date` 默认值的计算。默认 `Asia/Shanghai`                                 |

### 返回值

成功返回 `null`。

### 示例

```
popo-cli popo calendar_schedule_cancel scheduleId=123456789

popo-cli popo calendar_schedule_cancel scheduleId=123456789 cancelType=1 startTime=20260501
```

## popo_calendar_location_search

查询位置信息，用于在查询会议室时的locationId参数传递。

### 参数

无

### 返回值

Map<Sting,Long>
key 为 name，value 为 locationId。

### 示例

```
popo-cli popo calendar_location_search
```

## popo_calendar_user_info

查询当前用户信息

### 参数

无

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `uid` | String | 用户 uid（邮箱），可直接用于其他日历接口的 uid / participants 参数 |
| `name` | String | 真名 |
| `nickname` | String | 昵称 |
| `deptName` | String | 部门信息 |

### 示例

```
popo-cli popo calendar_user_info