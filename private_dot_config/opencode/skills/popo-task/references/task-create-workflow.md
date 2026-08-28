# POPO Task — 创建 / 更新工作流

> 适用 tool：`task_create`、`task_subtask_create`、`task_update`。
> 字段权威定义见 [`tool-reference.md`](./tool-reference.md)。

---

## 1. 创建任务（`task_create`）完整步骤

> ⚠️ 创建任务 ≠ 创建子任务。用户没说"子任务/加子任务/在 X 下新增"时走本节，**不**追问 parentTaskId。`task_create` 参数无 parentTaskId 字段。

```
Step 1  意图识别
        ─ 用户表达"建任务 / 加一条待办 / 派个任务"等 → 进入本流程

Step 2  解析输入
        ⚠️ 除标题外，以下字段均为**可选**。用户没提供的直接跳过，**不追问**。
        ├─ 标题（必须） — 缺则直接聊天反问（如"任务标题是什么？"），**禁止**用 ask_user_question（无输入框）
        ├─ 执行人 — 可选。见 §1.1。用户未提 → 默认当前用户（Step 3），**不追问**
        ├─ 项目 — 可选。见 §1.2。用户未提 → 不传，**不追问**
        ├─ 时间 — 可选。见 §1.3。用户未提 → 不传，**不追问**
        ├─ 优先级 — 可选。"紧急/高/中/低/无" → 1/2/3/4/0。用户未提 → 不传，**不追问**
        └─ 关注人 / 备注 — 可选。用户未提 → 不传，**不追问**

Step 3  执行人缺省处理（PRD §4.1）
        ├─ 用户**已显式提到执行人**（含"给/分配给/派给/由 X 来 / X 做"等）
        │   → 用解析到的 uid 数组填 assignees
        └─ 用户**未提任何执行人**
            ├─ 调 task_user_info 拿当前用户 uid
            ├─ assignees = [<当前用户 uid>]
            ├─ 回显摘要中明示："执行人：当前用户（自动）"
            └─ **不**追问"执行人是谁"

Step 4  回显完整摘要（铁律：必须，禁止跳过）
        ⚠️ 摘要表格必须作为**普通聊天消息**用 Markdown 正文输出，**禁止**塞进 ask_user_question
        的 question 或 description 字段（那两个字段只渲染纯文本，表格会变成一坨 `|` 分隔的文字）。

        先在正文输出下面的 Markdown 表格：

        **📋 创建任务确认**
        | 字段 | 内容 |
        |---|---|
        | 标题 | `<title>` |
        | 项目 | `<projectName>`（无则显示「个人任务」） |
        | 执行人 | `<name1>, <name2>`（未指定则显示「当前用户（自动）」） |
        | 关注人 | `<follower1>, <follower2>`（无则显示「—」） |
        | 开始时间 | `<startTime 格式化>`（无则显示「—」） |
        | 截止时间 | `<deadline 格式化>`（无则显示「—」） |
        | 优先级 | `<紧急/高/中/低/无>`（无则显示「无」） |
        | 备注 | `<remark>`（无则显示「—」） |

Step 5  紧接着调用 ask_user_question 提供选项（铁律：必须用选择器，禁止让用户手动输入）
        ├─ question: "确认创建此任务？"（纯文本一句话，**不要**再放表格/字段明细）
        ├─ 选项：["确认创建", "取消"]
        ├─ 用户选「确认创建」→ Step 6
        └─ 用户选「取消」→ 终止，不调接口
        （如需调整，用户可在取消后重新描述需求）

Step 6  调 task_create

Step 7  报告结果
        成功 → 回显 taskId + 标题
        失败分支：
        ├─ status=100403（无权限）→ 解析 message 中的 taskId/required/action，
        │   明确提示"无权限执行此操作 + 所需权限 + 操作类型 + 联系任务创建者/管理员"，不重试
        ├─ status=110200（读操作下游拦截，写操作少见但若出现同样明确提示）→ 同上不重试
        └─ 其他错误 → 报告服务端错误信息（不暴露内部细节）
```

### 1.1 用户名 → uid 解析子流程

依赖 fabric 全局工具 `popo_userinfo_search`（与 popo-im 同一工具，跨 skill 全局可调，不属任何 skill 独占）。

```
Step A  popo-cli popo userinfo_search keyword=<人名>

Step B  匹配处理（与 popo-calendar 同款）
        ├─ 唯一匹配 → 用其 uid
        ├─ 多匹配且 name 完全等于 keyword → 用该项 uid
        ├─ 多匹配无完全相等项 → 用 ask_user_question 展示候选列表让用户选（选项数量固定，适合选择器）
        └─ 零匹配 → 提示"未找到 <名字>，请确认拼写或换关键字"并停止
```

> ⚠️ **禁止**用 `popo_calendar_user_search` 代替（避免与 popo-calendar 触发耦合）；`userinfo_search` 是 fabric 全局工具。

### 1.2 项目名 → projectId 解析子流程

> `task_project_search` 的 `keyword` 为**可选**：用户报具体项目名时传 `keyword` 走按名搜索；用户只想"看下我的项目 / 列出项目"时不传 `keyword`，返回当前用户可见的全部项目（不含项目分组）。本子流程针对"报项目名 → 解析 projectId"场景。

```
Step A  popo-cli popo task_project_search keyword=<项目名>

Step B  匹配处理
        ├─ 唯一匹配 → 用其 projectId
        ├─ 多匹配且 name 完全等于 keyword → 用该项 projectId
        ├─ 多匹配无完全相等项 → 用 ask_user_question 展示候选让用户选（选项数量固定，适合选择器）
        └─ 零匹配 → "未找到名为 <X> 的项目，本期不支持 CLI 新建项目，
                    请到 POPO 客户端 任务面板 新建后重试。" 终止
```

### 1.3 时间解析规则

| 用户表述 | 计算口径 | `deadline` / `startTime` | `deadlineFormat` |
|---|---|---|---|
| "今天" | 本地今天 00:00:00 | 对应毫秒戳 | `1` |
| "明天" | 本地明天 00:00:00 | 对应毫秒戳 | `1` |
| "明天下午 3 点" | 本地明天 15:00:00 | 对应毫秒戳 | `2` |
| "下周一" | 本地下周一 00:00:00 | 对应毫秒戳 | `1` |
| "下周一上午 10 点" | 本地下周一 10:00:00 | 对应毫秒戳 | `2` |
| "6月30日" | 本地 6/30 00:00:00 | 对应毫秒戳 | `1` |
| "6月30日 18:00" | 本地 6/30 18:00:00 | 对应毫秒戳 | `2` |
| "本周五" | 本地本周五 00:00:00 | 对应毫秒戳 | `1` |
| 未指定时间 | — | 不传 | `0` 或不传 |

> 计算时区**统一用本地时区**；与 popo-calendar 的 ISO-8601 **不同**，写操作一律毫秒戳。

---

## 2. 创建子任务（`task_subtask_create`）

> ⚠️ 仅当用户说"子任务/加子任务/在 X 下新增"时走本节。必须指定 parentTaskId。

```
Step 1  解析父任务（必须）
        ├─ 用户给出明确父任务 ID / 名称 → 用该 ID（名称需先 task_list 定位）
        └─ 用户未指定 → 直接聊天反问（如"父任务 ID 是？"），**禁止**用 ask_user_question（无输入框）

Step 2  解析子任务清单（支持批量）
        ⚠️ 除标题外，其余字段均为**可选**。用户没提供的直接跳过，**不追问**。
        例："在任务 12345 下加 3 个子任务：A、B、C"
        → 3 条子任务，每条独立解析 title/assignees/deadline

Step 3  执行人处理（与 task_create 相同）
	        ⚠️ 子任务未指定执行人时默认当前用户（与 contract 对齐）

Step 4  回显批量摘要 + 调用 ask_user_question 提供选项（铁律：必须用选择器，禁止让用户手动输入）
        ⚠️ 摘要表格必须作为**普通聊天消息**用 Markdown 正文输出，**禁止**塞进 ask_user_question
        的 question / description 字段（纯文本渲染，表格会散架）。

        先在正文输出（同创建任务表格格式，多条子任务逐条展开）：

        **📋 创建子任务确认**
        | 序号 | 标题 | 所属父任务 | 执行人 | 截止时间 |
        |---|---|---|---|---|
        | 1 | `<title1>` | `<parentTaskId>` | `<name>` | `<格式化>` |
        | 2 | `<title2>` | `<parentTaskId>` | `<name>` | `<格式化>` |

        再调用 ask_user_question：
        question: "确认创建以上 N 条子任务？"（纯文本一句话，不放表格）
        选项：["确认创建", "取消"]
        └─ 取消 → 终止，不调接口

Step 5  逐条调用 task_subtask_create（不需要传 projectId — 父任务继承）
        每条调用后检查 status：
        ├─ 100403（无权限，required=CAN_EDIT，校验对象=parentTaskId）→ 解析 message，
        │   明确提示"无权限在父任务 <parentTaskId> 下创建子任务，请联系父任务创建者/管理员申请 CAN_EDIT 权限"，不重试，终止剩余子任务创建
        └─ 其他错误 → 报告服务端错误信息（不暴露内部细节）
```

**示例**

```bash
popo-cli popo task_subtask_create parentTaskId=t_12345 title=A
popo-cli popo task_subtask_create parentTaskId=t_12345 title=B
popo-cli popo task_subtask_create parentTaskId=t_12345 title=C
```

---

## 3. 更新任务（`task_update`）完整步骤

```
Step 1  定位任务
        ├─ 用户给 taskId → 直接用
        └─ 用户说"那个周报任务" → task_list 定位（必要时直接聊天反问澄清，**禁止**用 ask_user_question）

Step 2  task_detail 拿当前所有字段值（old）

Step 3  解析用户要改的字段（新）
        ├─ 单字段："改截止到周五"
        ├─ 多字段："改标题成 X，优先级改成高"
        ├─ 清空："取消截止时间" → deadline=0
        ├─ 执行人变更："把张三换成李四" → 先 task_detail 拿当前 assignees，替换后**全量传 assignees**（全量替换语义）
        ├─ 关注人变更：同上，**全量传 followers**
        ├─ 完成条件："改成任意一人完成就行" → completeCondition="any_one"
        └─ 循环规则/提醒：skill 不暴露入口，用户请求引导至客户端

Step 4  回显 diff + 调用 ask_user_question 提供选项（铁律：必须用选择器，禁止让用户手动输入）
        ⚠️ diff 表格必须作为**普通聊天消息**用 Markdown 正文输出，**禁止**塞进 ask_user_question
        的 question / description 字段（纯文本渲染，表格会散架）。

        先在正文输出 diff 表格：

        **📝 更新任务确认**
        | 字段 | 原值 | 新值 |
        |---|---|---|
        | 截止 | `<old>` | `<new>` |
        | 优先级 | `<old>` | `<new>` |
        | 执行人 | `<old_names>` | `<new_names>` |

        再调用 ask_user_question：
        question: "确认更新任务【<title>】？"（纯文本一句话，不放表格）
        选项：["确认更新", "取消"]
        ├─ 用户选「确认更新」→ Step 5
        └─ 用户选「取消」→ 终止，不调接口

Step 5  调 task_update — **仅传 taskId + 实际变化的字段**；assignees/followers 为全量替换，projectId 传 0 表示移出项目变为个人任务
        ⚠️ 不传未变化的字段，避免误覆盖

Step 7  报告结果
        成功 → 回显更新后的字段值
        失败分支：
        ├─ status=100403（无权限，required=CAN_EDIT，校验对象=taskId）→ 解析 message，
        │   明确提示"无权限更新任务 <taskId>，所需权限 CAN_EDIT，请联系任务创建者/管理员"，不重试
        └─ 其他错误 → 报告服务端错误信息（不暴露内部细节）
```

### 清空字段语义（重点）

| 语义 | 传值 |
|---|---|
| 清空截止 | `deadline=0` |
| 清空开始 | `startTime=0` |
| 清空所有执行人 | `assignees=[]`（空数组，全量替换语义） |
| 清空所有关注人 | `followers=[]`（空数组，全量替换语义） |
| 从项目移出变为个人任务 | `projectId=0` |
| 仅改截止粒度（仅日期 ↔ 日期+时间） | 同时传 `deadlineFormat` 新值 + 对应粒度的 `deadline` |

---

## 4. 完成任务（`task_finish`）/ 重开任务（`task_rebuild`）

> 写操作，**必须二次确认**（铁律 2）。两个接口互为逆操作：finish 未完成→已完成，rebuild 已完成→未完成。

### 4.1 完成任务（`task_finish`）

**触发语义**：用户说"把任务 X 标记完成 / 勾选完成 / 完成任务 X / 这个任务做完了"等。

**完整步骤**：

```
Step 1  调 task_detail taskId=<X> 拿当前状态：
          - title（回显用）
          - participants[]（执行人列表 + finished 状态）
          - subTasks[]（子任务，看是否有未完成子任务）
          - completeCondition（"all"/"any_one"）

Step 2  状态预检（⛔ 不满足则提示用户，不直接调 finish）：
          a) 任务已是"全部完成"状态（所有 participants.finished=true 且 completeCondition=all；
             或 any_one 模式下至少一人完成）→ 告知"任务已是完成状态"，不重复调 finish
          b) completeCondition="all" 且存在未完成执行人 → 提示"还有 N 个执行人未完成，确认要标记整个任务完成吗？"
          c) 存在未完成子任务 → 提示"还有 N 个子任务未完成，确认要标记父任务完成吗？"
          （b/c 属于提示性预检，用户确认后仍可调 finish）

Step 3  回显完整摘要（必含）：
          将完成任务【<title>】（taskId: <X>）
          当前完成进度：<已完成执行人数>/<总执行人数>
          [若有未完成子任务] ⚠️ 其下还有 <N> 个子任务未完成
          此操作不可撤销（可用"重开任务"恢复）

Step 4  调 ask_user_question 提供选项（铁律 2，禁止手动输入）：
          - 确认完成
          - 取消

Step 5  用户选"确认完成" → 调 task_finish taskId=<X>
Step 6  报告结果
        成功 → "任务【<title>】已标记完成"
        失败分支：
        ├─ status=100403（无权限，required=CAN_COMPLETE，校验对象=taskId）→ 解析 message，
        │   明确提示"无权限完成任务 <X>，所需权限 CAN_COMPLETE，请联系任务创建者/管理员"，不重试
        └─ 其他错误 → 报告服务端错误信息（不暴露内部细节）
```

```bash
# 完成任务
popo-cli popo task_finish taskId=t_12345
```

> 入参仅 `taskId`（int64，必填），返回 null（成功无 body）。

### 4.2 重开任务（`task_rebuild`）

**触发语义**：用户说"重开任务 X / 取消完成 / 这个任务还没做完 / 把任务 X 改回未完成"等。

**完整步骤**：

```
Step 1  调 task_detail taskId=<X> 拿当前状态：
          - title（回显用）
          - participants[]（看完成状态）

Step 2  状态预检：
          任务当前不是"已完成"状态（所有 participants.finished=false）→ 告知"任务当前未完成，无需重开"，不调 rebuild

Step 3  回显完整摘要（必含）：
          将重开任务【<title>】（taskId: <X>）
          当前状态：已完成
          重开后：状态变更为未完成，执行人完成记录将被清除

Step 4  调 ask_user_question 提供选项（铁律 2）：
          - 确认重开
          - 取消

Step 5  用户选"确认重开" → 调 task_rebuild taskId=<X>
Step 6  报告结果
        成功 → "任务【<title>】已重开（恢复为未完成）"
        失败分支：
        ├─ status=100403（无权限，required=CAN_COMPLETE，校验对象=taskId）→ 解析 message，
        │   明确提示"无权限重开任务 <X>，所需权限 CAN_COMPLETE，请联系任务创建者/管理员"，不重试
        └─ 其他错误 → 报告服务端错误信息（不暴露内部细节）
```

```bash
# 重开任务
popo-cli popo task_rebuild taskId=t_12345
```

> 入参仅 `taskId`（int64，必填），返回 null。
> ⚠️ **finish/rebuild 是任务级操作**：标记整个任务完成/未完成。对多执行人任务，按 `completeCondition` 语义判定（all=所有人完成才算完成，any_one=任意一人完成即算完成）。

### 4.3 确认选项模板

| 操作 | 选项1 | 选项2 | 回显必含 |
|---|---|---|---|
| 完成 | 确认完成 | 取消 | title + 当前完成进度 + ⚠️未完成子任务数（若有）+ "不可撤销（可重开）" |
| 重开 | 确认重开 | 取消 | title + 当前已完成状态 + "重开后执行人完成记录清除" |

---

## 5. 关键示例

```bash
# 创建（带执行人 + 截止）
popo-cli popo task_create title="周报 Q2 提交" \
  assignees="[\"alice@corp.com\"]" \
  deadline=1735660800000 deadlineFormat=2 priority=2

# 创建（未指定执行人 → 默认当前用户）
# 0) popo-cli popo task_user_info → uid=alice@corp.com
popo-cli popo task_create title="看完云协作 UX 计划表" \
  assignees="[\"alice@corp.com\"]" \
  deadline=1735660800000 deadlineFormat=1

# 子任务（批量）
popo-cli popo task_subtask_create parentTaskId=t_12345 title=方案讨论
popo-cli popo task_subtask_create parentTaskId=t_12345 title=接口对齐

# 更新（仅截止）
popo-cli popo task_update taskId=t_12345 deadline=1735747200000 deadlineFormat=2

# 清空截止
popo-cli popo task_update taskId=t_12345 deadline=0

# 完成任务（确认后调用）
popo-cli popo task_finish taskId=t_12345

# 重开任务（确认后调用）
popo-cli popo task_rebuild taskId=t_12345
```
