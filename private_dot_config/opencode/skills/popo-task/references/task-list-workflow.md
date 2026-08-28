# POPO Task — 列表查询工作流

> 适用 tool：`task_list`（浏览）、`task_search`（关键词搜索）。字段权威定义见 [`tool-reference.md` §8](./tool-reference.md#8-task_list--任务列表浏览四大快捷方式--项目内) / [§8b](./tool-reference.md#8b-task_search--关键词搜索任务)。

---

## 0. 接口路由：先选对接口

```
用户请求含 关键词 / 模糊标题匹配（"找标题带 X 的任务"、"搜 X"）
    → task_search（keyword 必填）
纯浏览（四大快捷方式 / 某项目下全部任务，无关键词）
    → task_list
```

⚠️ **两接口分页字段不同**：`task_list` 用 **`nextPageToken`**，`task_search` 用 **`scrollId`**；翻页时都作为下次 `pageToken` 回传，但取的字段不一样。

---

## 1. task_list 查询模型总图

```
┌──────────────────────────────────────────────────────────────┐
│ 第 1 层：navigatorId（四大快捷方式，对齐客户端左侧入口）      │
│   ├─ all      全部任务（默认）                                │
│   ├─ assignee 分配给我                                        │
│   ├─ follower 我关注的                                        │
│   └─ creator  我创建的                                        │
│   （服务端用当前用户翻译，skill 无需拿 uid）                  │
├──────────────────────────────────────────────────────────────┤
│ 第 2 层：projectId（可与 navigatorId 叠加：某项目 + 某快捷方式）│
├──────────────────────────────────────────────────────────────┤
│ 第 3 层：quickConditions（多值 AND）                          │
│   - unfinished / finished / assign_to_me /                   │
│     today_deadline / this_week_deadline                      │
├──────────────────────────────────────────────────────────────┤
│ 第 4 层：conditions（多 field AND，单 field values OR）        │
│   - assignee / assigner / follower / deadline / startTime /  │
│     alarmTime / project / priority [+ createTime/finished 高级]│
├──────────────────────────────────────────────────────────────┤
│ 第 5 层：Agent 端分组（不传给服务端，本地聚合展示）            │
│   - projectId / assignees / priority / deadlineBucket        │
└──────────────────────────────────────────────────────────────┘
```

> 第 1~4 层通过单次 `task_list` 调用传给服务端；第 5 层在 Agent 端对返回的 `list[]` 重组展示。
> `navigatorId` / `quickConditions` / `conditions` / `projectId` 之间均为 **AND** 叠加，可组合。

---

## 2. task_list 入口构造方式

### 2.1 四大快捷方式（navigatorId）

| 用户语义 | navigatorId |
|---|---|
| "全部任务 / 所有任务" | `all`（可省略） |
| "分配给我的任务" | `assignee` |
| "我关注的任务" | `follower` |
| "我创建的任务" | `creator` |

```bash
# ⛔ 默认隐藏已完成（铁律 6）：未提及完成状态时必须带 quickConditions=["unfinished"]
popo-cli popo task_list navigatorId=all quickConditions="[\"unfinished\"]"
popo-cli popo task_list navigatorId=assignee quickConditions="[\"unfinished\"]"
popo-cli popo task_list navigatorId=follower quickConditions="[\"unfinished\"]"
popo-cli popo task_list navigatorId=creator quickConditions="[\"unfinished\"]"

# 用户主动表达完成状态时按三档语义切换（见 §6）：
#   「看已完成」/「我已经完成的」→ quickConditions=["finished"]
#   「包含已完成」/「全部都看」→ 不传 finished/unfinished
```

> 服务端用当前用户（X-User-Email）翻译 navigatorId，**无需**先调 `task_user_info` 拿 uid。

### 2.2 某项目下所有任务（projectId）

需先 `task_project_search` 解析为 projectId。用户报项目名 → 传 `keyword=<项目名>`；用户只说"看下我的项目 / 列出项目" → 不传 `keyword` 列出全部可见项目，再让用户选。

```bash
# 用户已报项目名
popo-cli popo task_project_search keyword=Q3复盘
# 用户想先看有哪些项目（keyword 可空）
popo-cli popo task_project_search

# 某项目下所有任务（默认隐藏已完成）
popo-cli popo task_list projectId=123456 quickConditions="[\"unfinished\"]"
```

### 2.3 快捷方式 + 叠加过滤（混合用法）

四大快捷方式可再叠加 quickConditions / conditions / projectId（AND）。**默认场景（未提完成状态）必须把 `unfinished` 与其他值一起放进 quickConditions 数组**：

```bash
# 分配给我 + 本周截止 + 默认隐藏已完成（unfinished 与 this_week_deadline 一起放数组）
popo-cli popo task_list navigatorId=assignee \
  quickConditions="[\"unfinished\",\"this_week_deadline\"]"

# 某项目 + 我创建的 + 本周截止 + 默认隐藏已完成
popo-cli popo task_list projectId=123456 navigatorId=creator \
  quickConditions="[\"unfinished\",\"this_week_deadline\"]"

# 分配给我 + 高优先级（conditions）+ 默认隐藏已完成
popo-cli popo task_list navigatorId=assignee \
  quickConditions="[\"unfinished\"]" \
  conditions="[{\"field\":\"priority\",\"values\":[2]}]"

# 用户主动要「包含已完成」（不传 finished/unfinished）+ 本周截止
popo-cli popo task_list navigatorId=assignee \
  quickConditions="[\"this_week_deadline\"]"
```

---

## 3. task_search 关键词搜索

有关键词/模糊标题需求走 `task_search`（`keyword` 必填），同样可叠加 navigatorId / quickConditions / conditions / querySort（AND）。**默认场景同样必须带 `quickConditions=["unfinished"]` 隐藏已完成**（铁律 6 三档语义与 `task_list` 完全一致）。

```bash
# 全局搜索（默认隐藏已完成，pageSize=50 拉满 — 见 §8.2 自动续拉兜底）
popo-cli popo task_search keyword=周报 quickConditions="[\"unfinished\"]" pageSize=50

# 项目内搜索（默认隐藏已完成，pageSize=50 拉满）
popo-cli popo task_search keyword=上线 projectId=123456 quickConditions="[\"unfinished\"]" pageSize=50

# 用户主动要搜「已完成」（仅已完成，pageSize=50 拉满）
popo-cli popo task_search keyword=周报 navigatorId=assignee quickConditions="[\"finished\"]" pageSize=50

# 用户主动要「包含已完成」（两者都展示，pageSize=50 拉满）
popo-cli popo task_search keyword=周报 navigatorId=assignee pageSize=50

# 叠加：关键词 + 分配给我 + 默认隐藏已完成 + 按截止升序 + pageSize=50 拉满
popo-cli popo task_search keyword=需求评审 navigatorId=assignee \
  quickConditions="[\"unfinished\"]" \
  querySort="{\"field\":\"deadline\",\"order\":\"asc\"}" pageSize=50
```

> ⚠️ `task_search` 分页用 **`scrollId`**（见 §8），与 `task_list` 的 `nextPageToken` 不同。
> ⚠️ 查"指定他人"创建/关注的任务（非当前用户）时，navigatorId 无法表达，用 `conditions.assigner`/`follower` + 对方 uid（先 `task_user_info` 或 `userinfo_search` 拿 uid）。

---

## 4. `quickConditions` 暴露策略

| 值 | 用户语义入口 | 处理 |
|---|---|---|
| `assign_to_me` | "分配给我" | ⚠️ 优先用 **`navigatorId=assignee`**（更贴合客户端快捷方式）；`assign_to_me` 作为叠加过滤时才用 |
| `today_deadline` | ✅"今天截止" | 主动暴露（作为叠加过滤） |
| `this_week_deadline` | ✅"本周截止" | 主动暴露（作为叠加过滤） |
| `finished` | ✅"已完成" | 仅用户主动说"已完成 / 历史 / 看已完成 / 我已经完成的"时使用（三档第 2 档） |
| `unfinished` | ⛔ **默认必带**（铁律 6） | 用户**未提及完成状态时必须自动追加**到 quickConditions（作为实现细节，不向用户提及）；叠加其他 quickConditions 值时一并放入数组。**不**作为用户语义入口暴露 |

**多值 AND 语义**（已与服务端 contract 对齐）：
- `["today_deadline", "unfinished"]` = 今天截止的 **且** 未完成的
- `["unfinished", "this_week_deadline"]` = 未完成的 **且** 本周截止的

> "分配给我 / 我关注的 / 我创建的"是**入口**（navigatorId），今天截止 / 本周截止 / 已完成是**叠加过滤**（quickConditions）—— 两者可组合。
> ⛔ **默认必带 `unfinished`** 是强约束（铁律 6），不是可选项；只要用户没主动表达完成状态，无论叠加了多少其他 quickConditions 值，都必须把 `unfinished` 一起放进去。

---

## 5. `conditions` 暴露策略

conditions 用于更细的自定义过滤（可叠加在任一 navigatorId 之上）：

| field | values 期望 | 典型语义 |
|---|---|---|
| `assignee` | uid[] | 执行人是 X / Y |
| `assigner` | [uid] | 分配人/创建人是**指定他人**（查自己"我创建的"用 `navigatorId=creator`） |
| `follower` | uid[] | 关注人是**指定他人**（查自己"我关注的"用 `navigatorId=follower`） |
| `deadline` | 时间枚举 / [ms,ms] | 截止时间在 X 范围 |
| `startTime` | 时间枚举 / [ms,ms] | 开始时间在 X 范围 |
| `alarmTime` | 时间枚举 / [ms,ms] | 提醒时间在 X 范围 |
| `project` | projectId[] | 在项目 P1/P2/... |
| `priority` | int[]（`1..4`） | 优先级 是 无/紧急/高/中/低 |

**优先级数字对照**

| 用户语义 | values |
|---|---|
| 紧急 | `[1]` |
| 高 | `[2]` |
| 中 | `[3]` |
| 低 | `[4]` |
| 无 | `[0]` |
| 高 + 紧急 | `[1, 2]`（同 field 的 values 之间 OR）|

**高级（不主动暴露）**

| field | 处理 |
|---|---|
| `createTime` | 用户问"按创建时间过滤" → 优先用 `startTime` 时间枚举（如 `future_7_days`）覆盖；用户显式点名"创建时间"才说明一期主流程不暴露，引导其使用 `startTime` 或客户端 |
| `finished` | 与 `quickConditions.finished` / `unfinished` 语义重复，**不**重复暴露 |

> `project` field 必须传 **projectId**，不是项目名 — 用户报项目名时先经 `task_project_search` 解析。

---

## 6. "默认不展示已完成" 规则（铁律 6 三档语义）

`task_list` 与 `task_search` **共用**本规则。调用前必须按下表判定 `quickConditions` 中 `unfinished` / `finished` 的取舍：

| 档位 | 用户语义（触发词） | quickConditions 处理 |
|---|---|---|
| **第 1 档：默认** | 用户**未提及**完成状态（"看任务 / 列任务 / 分配给我的 / 本周截止的 / 搜 X"等） | ⛔ **必须追加 `unfinished`**（与其他 quickConditions 值一起放数组）；不向用户提及"已加 unfinished" |
| **第 2 档：仅已完成** | 用户主动说「看已完成」/「我已经完成的」/「已完成」快捷筛选/「历史任务」/「已完成的任务」 | `quickConditions=["finished"]`（**移除 `unfinished`**） |
| **第 3 档：包含已完成** | 用户主动说「包含已完成任务」/「全部都看（含已完成）」/「已完成的也一起看」/「连同已完成的都列出」 | `quickConditions` **既不含 `finished` 也不含 `unfinished`**（两者都展示） |

```
判定流程：
  IF 用户语句含「已完成/历史/我已经完成的」类完成状态提及:
      IF 语义是"仅看已完成"（看已完成 / 我已经完成的 / 已完成筛选 / 历史任务）
          → quickConditions=["finished"]（移除 unfinished）          [第 2 档]
      ELIF 语义是"包含已完成"（包含已完成 / 全部都看 / 也一起看）
          → 不传 finished/unfinished                                  [第 3 档]
  ELSE:
      → quickConditions 追加 unfinished（默认隐藏已完成）              [第 1 档]

叠加其他 quickConditions 值时：
  - 第 1 档：unfinished 与其他值一起放数组，如 ["unfinished","this_week_deadline"]
  - 第 2 档：仅放 finished + 其他值，如 ["finished","this_week_deadline"]
  - 第 3 档：仅放其他值，如 ["this_week_deadline"]（不传 finished/unfinished）
```

> ⚠️ **判定要点**：用户语句只要出现"已完成"三字就要进入第 2/3 档判定；区分"仅看已完成"还是"包含已完成"看是否同时出现"全部/都看/包含/一起/连同"等包含性词。模糊时优先按第 2 档（仅已完成）处理，因为"已完成"单独出现时默认语义是"看那些已完成的"。
> ⚠️ **不向用户提及 `unfinished`**：第 1 档是透明实现细节，回显/渲染时不出现"已加未完成筛选"字样。

---

## 7. 列表展示规范

### 7.1 表格列定义

> ⛔⛔ **默认必须输出「单个统一表格」。** 无论查回来多少任务、状态/优先级/项目是否混杂，**一律汇总进同一张表**，列完全一致。**严禁**按已完成/未完成、优先级、项目、执行人等自行拆成多张表（拆分只在用户**显式要求"按 X 分组"**时才做，见 §7.4）。

所有列表输出统一使用以下 **10 列**表格，列顺序与列名固定，**禁止**增删列或改列名：

| 列名 | 来源 | 格式化 | 缺失/0 值处理 |
|------|------|--------|-------------|
| # | 行序号 | 从 1 递增 | — |
| 任务ID | `taskId` | 原样 | — |
| 标题 | `title` | 带缩进前缀（§7.2） | — |
| 项目 | `projectName` | 原样 | 无则显示「个人任务」 |
| 分配人 | `assigner.name` | 原样 | `-`（null 时） |
| 执行人 | `assignees[].name` | 多值用"、"拼接 | `-`（null 或空数组时） |
| 优先级 | `priority` | **严格映射**：`1`→紧急 `2`→高 `3`→中 `4`→低 `0`→无 | 0 时显示 `-` |
| 开始时间 | `startTime` | 用 §5.0 命令换算 `YYYY-MM-DD HH:mm` | 0/null 时显示 `-` |
| 截止时间 | `deadline` | `deadlineFormat=1`→`YYYY-MM-DD`，`=2`→`YYYY-MM-DD HH:mm` | `deadline=0` 时显示 `-` |
| 创建时间 | `createTime` | 用 §5.0 命令换算 `YYYY-MM-DD` | — |
| 状态 | `completed` | `1`→✅ `0`→⬜ | — |

> ⛔⛔ **时间列必须用命令换算，严禁心算。** 拿到回包后，把 `deadline`/`startTime`/`createTime` 交给 [`task-detail-render.md` §5.0 标准换算命令](./task-detail-render.md#50-标准换算命令复制即用一次批量转多个)，用输出字符串填表。
> ⏱ **单位按接口区分**：`task_list`（McpTaskItem）为**毫秒**（直接传入）；`task_search`（AgentQueryTaskItem）为**秒**（传入前 **×1000**）。
>
> ⛔⛔ **优先级标签是固定枚举，禁止改叫法。** `priority` 只能按 `1`→**紧急**、`2`→**高**、`3`→**中**、`4`→**低**、`0`→**无** 映射。**严禁**输出"最高/普通/重要/一般/低优先级/P0/P1"等任何其他叫法或客户端别名，必须原样用 紧急/高/中/低/无 这五个词。

### 7.2 父子任务缩进 + 树形分组

两个接口的父子结构来源不同，但**展示效果一致**（有父子关系就以树形缩进展示）：

- **`task_list`（McpTaskItem）**：回包**已含嵌套 `subTasks` 子任务树**，直接递归展开，**无需**本地按 parentId 重组。
- **`task_search`（AgentQueryTaskItem）**：回包为**扁平列表**，需 Agent 本地按 `parentId` 重组为树形。

```
task_list：直接递归 subTasks
1. 根任务 = list[] 顶层各项；其 subTasks[] 即其子任务（可再嵌套）
2. 排序：同层按 createTime 倒序
3. 缩进前缀见下

task_search：本地重组
1. 按 parentId 分组：无 parentId 的为根任务，有 parentId 的挂到对应父任务下
2. 子任务 parentId 在 list[] 中找不到对应父任务时，当普通根任务展示（不做孤儿标记）
3. 排序：父任务按 createTime 倒序，子任务按 createTime 倒序

缩进前缀（两接口通用）：
   - 独立任务（!isParent && !parentId）→ 无前缀
   - 父任务（isParent 或 subTasks 非空）→ 📂 前缀
   - 子任务                            → ├─ 前缀 + 缩进 2 空格（非尾项）/ └─ 前缀 + 缩进 2 空格（尾项）
```

### 7.3 表格渲染示例（默认：全部任务汇总进一张表）

```
| # | 任务ID | 标题 | 项目 | 分配人 | 执行人 | 优先级 | 开始时间 | 截止时间 | 创建时间 | 状态 |
|---|--------|------|------|--------|--------|-------|---------|---------|---------|:--:|
| 1 | 90001 | 📂 测试二下 | Q3复盘 | grp130 | grp130 | 高 | - | - | 2026-06-30 | ⬜ |
| 2 | 90002 | &nbsp;&nbsp;└─ 📎 二下子任务 | Q3复盘 | grp130 | - | 中 | - | - | 2026-06-30 | ⬜ |
| 3 | 90003 | CLI全字段测试-你好 | 个人任务 | 邵峰 | grp130、邵峰、timer(戚桂旭) | 紧急 | 2025-10-28 09:00 | 2025-10-30 08:00 | 2026-06-29 | ⬜ |
| 4 | 90004 | 啊撒 | 个人任务 | grp130 | - | - | - | 2025-07-17 | 2025-07-17 | ✅ |
```

> 📂 父任务 | 📎 子任务 | ⚠️ 父任务已删除（孤儿）
> 已完成（✅）与未完成（⬜）、不同优先级/项目**混在同一张表**，**不**拆分。

### 7.4 分组展示（⚠️ 仅当用户显式要求"按 X 分组"时）

> ⛔ **默认不分组**：普通的"看任务/列任务/查任务"一律走 §7.1 单张统一表，**不要**主动分组。
> 只有用户**明确说**"按项目分组 / 按执行人分组 / 按优先级分组 / 按截止时间分组"时才拆分。
> **分组时每个分组内仍用 §7.1 完全相同的 10 列表格**（列名、列顺序一致），只是按维度拆成多张同构表 + 各加一个分组标题。服务端**不**支持 `groupBy`，分组在 Agent 端本地完成。

**7.4.1 按 `projectId`（"按项目分组"）**：`key = projectName or "个人任务"`，每组一张 10 列表，组内按 deadline 升序。

**7.4.2 按 `assignees`（"按执行人分组"）⚠️ 重点**：展开任务项的 `assignees[]`（`task_list`=McpTaskItem、`task_search`=AgentQueryTaskItem，均含 `assignees[]`），**一条任务在多个执行人组下各出现一次**；`assignees` 为空归入"未分配"组。

> 🚫 **绝对禁止**用 `assigner`（单值分配人/创建人）作"执行人"分组维度 — PRD/contract 语义陷阱。

**7.4.3 按 `deadline`（"按截止时间分组"）**：桶 = 已过期 / 今日 / 本周 / 本月 / 更晚 / 无（基于本地今天）。

**7.4.4 按 `priority`（"按优先级分组"）**：`key = {1:"紧急",2:"高",3:"中",4:"低",0:"无"}[priority]`，组顺序 紧急 → 高 → 中 → 低 → 无。

---

## 8. 分页处理

⚠️ **两接口分页字段不同，翻页取值别混**：

| 接口 | 判断是否有更多 | 下一页游标（回传为 `pageToken`） |
|---|---|---|
| `task_list` | `hasMore` | **`nextPageToken`**（=本页最后一条 taskId，空串表示无更多） |
| `task_search` | `more` / `hasMore` | **`scrollId`** |

### 8.1 `task_list` 分页（手动加载更多）

```
Step 1  调 task_list（首页）
        → 返回 list[]、hasMore、nextPageToken

Step 2  渲染结果时若 hasMore=true（亦可判 nextPageToken 非空）
        → 在末尾提示 "还有更多结果，回复"加载更多"继续"

Step 3  用户说"加载更多"
        → 用上次 nextPageToken 作为 pageToken 调下一页（其他参数保持一致）

Step 4  循环直到无更多或用户停止
```

```bash
# task_list 首页 + 续拉（默认隐藏已完成，续拉时其他参数保持一致）
popo-cli popo task_list navigatorId=assignee quickConditions="[\"unfinished\"]"
popo-cli popo task_list navigatorId=assignee quickConditions="[\"unfinished\"]" pageToken=<上次nextPageToken>
```

### 8.2 `task_search` 分页（⛔ 自动续拉兜底 + 本地相关度重排）

> **背景**：服务端 `task_search` 底层走 ES，`matchQuery(title)` 分词后 **OR** 匹配（部分 token 命中也算命中），且按 `todoCreateTime DESC` 排序（非相关度）。首页 20 条极易全是"部分匹配但时间更新"的任务，用户真正想要的完整匹配若 `createTime` 靠后，被挤到后续页。**必须自动兜底**，否则用户以为"没搜到"。

**三步兜底流程**：

```
Step 1  首页调用：pageSize=50（拉满上限，减少分页次数）
        popo-cli popo task_search keyword=<关键词> quickConditions="[\"unfinished\"]" pageSize=50
        → 返回 list[]、hasMore/more、scrollId

Step 2  本地完整匹配判定 + 重排
        a. 对 keyword 做中文分词（按常见分词粒度切，如"写周报任务记录"→["写","周报","任务","记录"]）
        b. 对 list[] 每条任务的 title 计算命中 token 数：
           - 完整匹配（allTokensHit=true）：title 含全部分词 token
           - 部分匹配（allTokensHit=false）：title 仅含部分 token
        c. 本地重排：完整匹配项置顶（组内保持原 createTime 倒序），部分匹配项在后
        d. 渲染重排后的列表

Step 3  自动续拉判定（⛔ 必做，不等用户手动"加载更多"）
        IF 首页 hasMore=true 且 首页无完整匹配项（allTokensHit 全为 false）:
            → 自动用 scrollId 作 pageToken 续拉下一页（其他参数保持一致）
            → 新页 list[] 同样做 Step 2 重排
            → 合并累计结果，再次判定是否仍无完整匹配
            → 循环续拉，上限 3 页（含首页累计 150 条）或 hasMore=false 为止
        ELIF 首页已有完整匹配项:
            → 不自动续拉，按 §8.1 手动模式提示"加载更多"
        ELSE (首页无更多):
            → 不续拉

Step 4  渲染最终结果
        - 合并所有已拉页的 list[]，统一做 Step 2 本地重排后渲染
        - 若累计结果中仍无完整匹配（3 页拉完仍全部分匹配）：
          → 在表格上方明示"未找到标题完整含'<关键词>'的任务，以下为部分关键词匹配结果（已按相关度重排）"
        - 若累计结果中有完整匹配：
          → 正常渲染（完整匹配已置顶，无需额外提示）
        - 若累计 hasMore=true 且已达 3 页上限仍未找到完整匹配：
          → 末尾提示"已自动加载 3 页未找到完整匹配，如需继续请回复'加载更多'"
          → 后续按 §8.1 手动模式续拉
```

```bash
# task_search 首页（pageSize=50 拉满，默认隐藏已完成）
popo-cli popo task_search keyword=写周报任务记录 quickConditions="[\"unfinished\"]" pageSize=50

# 自动续拉（首页无完整匹配时，用 scrollId 作 pageToken）
popo-cli popo task_search keyword=写周报任务记录 quickConditions="[\"unfinished\"]" pageSize=50 pageToken=<上次scrollId>
```

> ⛔ **自动续拉仅适用于 `task_search`**：`task_list` 是纯浏览无关键词，无"完整匹配"概念，不自动续拉，仍走 §8.1 手动模式。
> ⛔ **完整匹配判定在 Agent 端本地做**：服务端 ES 返回的是 OR match 结果，Agent 拿到后按分词 token 全命中判定，**不**依赖服务端相关度评分。
> ⚠️ **3 页上限是为避免大量调用拖慢响应**：超 3 页仍无完整匹配时停止自动续拉，转手动。
> ⚠️ **本地分词为简化实现**：按常见中文分词粒度切 token 即可，无需引入分词库；英文按空格/标点切。判定时 token 在 title 中出现即可（不要求连续）。
