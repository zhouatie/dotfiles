# POPO Task — 详情渲染规范

> 适用 tool：`task_detail`。字段权威定义见 [`tool-reference.md`](./tool-reference.md#7-task_detail--任务详情)。

---

## 1. 稳定段落顺序

详情展示**必须**严格按以下段落顺序，每个段落独立成段，缺失的字段对应段落整段省略（不留空标签）：

```
1. 标题            ── title
2. 项目            ── projectName（若无则整段省略）
3. 执行人 + 进度    ── participants[].name，若 participants.length > 1 附加"完成进度 X/Y"
4. 关注人          ── followers[].name 用"、"拼接（详见 §4b）
5. 开始时间        ── startTime（TaskVo: **毫秒** → 用 §5.0 命令换算，按 startTimeFormat 决定粒度）
6. 截止时间        ── deadline（TaskVo: **毫秒** → 用 §5.0 命令换算，按 deadlineFormat 决定粒度）
7. 提醒时间        ── alarm.alarmTimestamp
8. 优先级          ── priority **严格映射**：1→紧急 / 2→高 / 3→中 / 4→低 / 0→无（禁止"最高/普通/重要/P0"等其他叫法）
9. 备注            ── remark（多行原样展示）
10. 附件            ── attachments[]（详见 §2）
11. 子任务          ── subTasks[]（详见 §3）
12. 评论数 / 日志数 ── commentCount / logCount（一行汇总：评论 N · 日志 M）
```

> 若用户问"任务详情"则按完整顺序渲染；若用户问"截止时间是什么"则只回答相关段落（不必整体展开）。
> ⛔ **渲染输出用 markdown 结构化格式（标题/粗体/列表），不要把整段内容塞进代码块**（见 §6）。

---

## 2. 附件清单渲染

```
- 仅展示 attachments[].name（按数组顺序）
- 不展示 url / docUrl / fileId / objectKey / md5 等内部字段
- 不下载附件文件
- 若 attachments 为空 → 整段省略，不展示"附件：无"
```

**渲染格式**（markdown 无序列表）：

```markdown
**附件**：
- 周报.pdf
- 截图.png
- 设计稿（云空间）
```

> 用户要求"下载附件" → 拒绝并告知"一期暂不支持附件下载，请在 POPO 客户端打开任务下载"（PRD ❌ 列表）。

---

## 3. 子任务进度计算

```
total       = subTasks.length
done        = count(subTasks where finished == true)
progress    = done / total
显示文本    = "子任务进度 done/total"（例 "子任务进度 2/5"）
```

子任务列表渲染（按数组顺序，markdown 无序列表，**每项须完整展示名称/执行人/截止时间/完成状态四要素**）：

```markdown
**子任务**（done/total）：
- ✅ <title> — 执行人：<names> — 截止：<deadline 本地格式化> — 已完成
- ⬜ <title> — 执行人：<names> — 截止：<deadline 本地格式化> — 未完成
```

> 子任务四要素取值：
> - **名称**：`subTasks[i].title`
> - **执行人**：`subTasks[i].assignees[].name` 多值用"、"拼接；为空显示"未分配"
> - **截止时间**：`subTasks[i].deadline`（**毫秒**，用 §5.0 命令换算）；为 `0` 或 `deadlineFormat=0` 显示"未设置"
> - **完成状态**：`subTasks[i].finished === true` → 行首 ✅ + 尾部"已完成"；`false` → 行首 ⬜ + 尾部"未完成"
>
> 子任务为空时整段省略，**不**展示"子任务进度 0/0"。
> ⛔ **四要素缺一不可**：详情场景需完整展示每个子任务全貌，禁止省略任一字段（即便执行人为空/截止未设也要显式标"未分配"/"未设置"）。

---

## 4. 执行人 + 进度（重点）

```
单执行人:
  执行人：<name>            ← 不附加进度

多执行人（participants.length ≥ 2）:
  执行人：<name1>、<name2>（完成进度 N/M）
  N = count(participants where finished == true)
  M = participants.length
```

**渲染格式**（作为详情段落的一行，粗体标签 + 值）：

```markdown
**执行人**：Alice、Bob（完成进度 1/2）
```

> ⚠️ 这里的进度是 **执行人完成进度**（多人 task 中各执行人独立打勾），**不是**子任务进度，两者不要混淆。

---

## 4b. 关注人渲染

`followers[]` 含 `uid`、`name`。仅展示 `name`，多人用中文顿号"、"拼接：

```markdown
**关注人**：张三、李四、王五
```

> 关注人为空（数组为空） → 整段省略，**不**展示"关注人：无"。
> 不要展示 `uid`（内部标识，对用户无意义）。

---

## 5. 时间格式化

> ⛔⛔ **铁律：时间戳必须用命令程序化换算，严禁心算/口算/估算。**
>
> 服务端返回的是 Unix 时间戳（整数）。**禁止**凭记忆的锚点（如"1700000000≈2023年"）去手推日期——这样几乎必然错（差几天 / 时区错算）。**必须**把时间戳交给下面的命令换算，拿命令输出的字符串直接填表。

### 5.0 标准换算命令（复制即用，一次批量转多个）

渲染任何列表 / 详情 / 评论 / 日志前，先把本次要显示的所有时间戳丢给 `node` 批量换算：

```bash
# 用法：把每个时间戳统一转成"毫秒"后传入（秒 → 先 ×1000）；withTime=true 出 "YYYY-MM-DD HH:mm"，false 出 "YYYY-MM-DD"
node -e "
const tz='Asia/Shanghai';
const fmt=(ms,withTime)=>{
  const s=new Date(Number(ms)).toLocaleString('sv-SE',{timeZone:tz}); // 'YYYY-MM-DD HH:mm:ss'
  return withTime ? s.slice(0,16) : s.slice(0,10);
};
// ↓↓↓ 按实际回包替换：毫秒直接填，秒 ×1000
console.log('deadline  =', fmt(1751594400000, true));
console.log('startTime =', fmt(1751500800000, false));
console.log('createTime=', fmt(1751500800000, false));
"
```

- **`node` 不可用时的兜底**（bash/GNU date，秒级）：
  ```bash
  TZ=Asia/Shanghai date -d @<秒时间戳> "+%Y-%m-%d %H:%M"   # 毫秒需先 /1000
  ```
- 换算完拿输出字符串填表，**不要**再对结果做任何手工加减。

> ⛔ **绝对禁止原样输出时间戳，也绝对禁止心算。** 所有时间字段必须经上面的命令转换为本地时区（Asia/Shanghai）可读格式。
>
> ⚠️ **时间单位不统一，传入 `fmt` 前先按下表把秒 ×1000 归一成毫秒：**

| 接口 | 字段 | 单位 | 传入 fmt 前处理 |
|------|------|:--:|------|
| `task_detail` (TaskVo) | `startTime`、`deadline` | **毫秒** | 直接传 |
| `task_detail` (TaskVo) | `taskCreateTime`、`sourceAddrTimestamp` | **毫秒** | 直接传 |
| `task_list` (McpTaskItem) | `startTime`、`deadline`、`createTime` | **毫秒** | 直接传 |
| `task_list` (McpTaskItem) | `completeTime`（任务级） | 恒 null | 取 `assignees[].completeTime` |
| `task_list` (McpTaskItem) | `assignees[].completeTime` | **毫秒** | 直接传 |
| `task_search` (AgentQueryTaskItem) | `startTime`、`deadline`、`createTime` | **秒** | **×1000** |
| `task_search` (AgentQueryTaskItem) | `completeTime` | **毫秒** | 直接传 |
| `task_search` (AgentQueryTaskItem) | `assignees[].completeTime` | **秒** | **×1000** |
| 评论/日志 (EditRecord) | `timestamp` | **毫秒** | 直接传 |
| 评论/日志 (EditRecordDetail) | `newDeadline`、`newStartTime` 等 | **毫秒** | 直接传 |

**计算自检**：① 单位对了吗（秒有没有 ×1000）？② 是不是用命令输出、而非手算？两条都过才可填表。

| `deadlineFormat` | 显示样式（本地时区） |
|---|---|
| `1`（仅日期） | `YYYY-MM-DD` |
| `2`（日期+时间） | `YYYY-MM-DD HH:mm` |
| `0` 或字段为 `0` | 整段省略，**不**展示"未设置" |

> `task_detail` / 评论 / 日志中的时间统一显示 `YYYY-MM-DD HH:mm`（不区分粒度）。

---

## 6. 完整示例

> ⛔⛔ **基本信息字段排版强约束（违反则堆成一行、可读性极差）**：
> - 基本信息（项目 / 执行人 / 开始时间 / 截止时间 / 提醒时间 / 优先级 / 备注）**每个字段独占一行**，**行间必须空一行**（markdown 段落分隔）。相邻字段行若无空行，渲染器会把多个字段合并成一行连续文本（见下方 ❌ 反例）。
> - 字段名必须用 `**粗体**` 包裹：`**执行人**：值`。**禁止**输出裸文本 `执行人：值`（无粗体）。
> - **禁止**把多个字段挤在同一行（如 `执行人：X 开始时间：Y 截止：Z`）。
>
> ❌ **反例（Agent 实际输出过的问题，禁止照搬）**：
> ```
> 执行人：grp130、韩冰凯（完成进度 1/5） 开始时间：2026-07-02 截止时间：2026-07-23 优先级：紧急 备注： 每周工作内容总结
> ```
> ↑ 字段间无空行 + 无粗体标签 → 渲染成一行，可读性差。
>
> ✅ **正例（必须照此排版）**：见下方代码块，每个 `**字段**` 独立一段、行间空一行。

```markdown
## 周报 Q2 提交

**项目**：研发周报

**执行人**：Alice、Bob（完成进度 1/2）

**关注人**：Carol、David

**开始时间**：2026-06-28

**截止时间**：2026-06-30 18:00

**优先级**：高

**备注**：包含本季度三大里程碑回顾

**附件**：

- 周报模板.docx
- Q2 数据.xlsx

**子任务**（1/2）：

- ✅ 数据收集 — 执行人：Alice — 截止：2026-06-29 — 已完成
- ⬜ 撰写正文 — 执行人：Bob — 截止：2026-06-30 — 未完成

---

💬 评论 5 · 📋 日志 12
```

> 字段缺失时对应整段省略（不留空标签、不留"未设置"）；`deadlineFormat=0` 时截止时间整段省略。
> 备注多行时：第一行紧跟 `**备注**：` 同行，后续行换行（不必每行空一行）。
> 附件 / 子任务列表项之间无需空行（列表本身自带分行）；但 `**附件**：` 标签行与第一个 `- ` 项之间要空一行，`**子任务**（x/y）：` 同理。
