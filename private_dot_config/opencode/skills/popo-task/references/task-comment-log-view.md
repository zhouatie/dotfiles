# POPO Task — 评论 / 日志渲染规范

> 适用 tool：`task_comment_list`、`task_log_list`（均为**只读**）。
> 字段权威定义见 [`tool-reference.md`](./tool-reference.md#9-task_comment_list--评论只读)。

---

## 0. 数据结构说明

评论和日志接口返回相同的 `EditRecord` 结构，核心字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `operatorName` | string | 操作者昵称 |
| `timestamp` | int64 | 操作时间（EditRecord: **毫秒**，`new Date(ts)` 直接转换） |
| `eventType` | int | 事件类型枚举（见 §2.1） |
| `eventDetail` | object | 事件详情（见下表） |
| `aiOperated` | bool | 是否 AI 助手（MCP 入口 `/v1/mcp/task/**`）触发产生。**仅日志有意义**（`task_log_list`），评论场景（`task_comment_list`）恒 false。`true` 时日志渲染在操作时间后加 ✦ 标识（见 §2.4） |

**`eventDetail` 常用字段：**

| 字段 | 用途 | 出现场景 |
|---|---|---|
| `content` | 评论内容（POPO标签文本） | `eventType`=19,20 |
| `commentId` | 评论 ID | `eventType`=19,20 |
| `replyToCommentId` | 被回复的评论 ID（非空=回复） | `eventType`=19 |
| `replyToCommentCreatorName` | 被回复者昵称 | `eventType`=19 |
| `newTitle` | 新标题 | `eventType`=2 |
| `prevTitle` | 原标题 | `eventType`=2 |
| `newDeadline` / `prevDeadline` | 新/原截止时间（EditRecordDetail: **毫秒**） | `eventType`=8,9,10 |
| `newDeadlineFormat` / `prevDeadlineFormat` | 时间格式 1=仅日期 2=日期时间 | `eventType`=8,9,10 |
| `newStartTime` / `prevStartTime` | 新/原开始时间（EditRecordDetail: **毫秒**） | `eventType`=32,33,34 |
| `newStartTimeFormat` / `prevStartTimeFormat` | 时间格式 | `eventType`=32,33,34 |
| `participants` | 参与人数组 `[{name,...}]` | `eventType`=3,4,35,36,37,38,42 |
| `name` | 单人名称 | `eventType`=31 |
| `newCompleteCondition` | 完成方式 `"all"`/`"any_one"` | `eventType`=39 |
| `newFinishPercent` | 完成度 0-1 | `eventType`=17,40,41 |
| `projectName` | 项目名称 | `eventType`=51,52 |
| `newRrule` / `prevRrule` | 循环规则 | `eventType` 含 rrule 变更时 |
| `newRemark` / `prevRemark` | 备注 | `eventType` 含备注变更时 |
| `newPriority` / `prevPriority` | 优先级 | `eventType` 含优先级变更时 |

---

## 1. 评论渲染

`task_comment_list` 返回评论类 EditRecord（`eventType` = 19 普通评论 或 20 删除评论）。

按 `timestamp` **倒序**展示（最新的在最上）。

> ⛔⛔ **绝对禁止原样输出时间戳，也绝对禁止心算。** 必须将 `timestamp`（EditRecord: 毫秒）用 [`task-detail-render.md` §5.0 命令](./task-detail-render.md#50-标准换算命令复制即用一次批量转多个)换算为 `YYYY-MM-DD HH:mm`。
> ⛔ **渲染输出用 markdown 结构化格式**（粗体操作人 + 引用块内容），**不要**把整段塞进纯文本代码块（会导致文本堆积、无法区分层级）。

### 1.1 普通评论（`eventType = 19`，`replyToCommentId` 为空）

```markdown
**<operatorName>** · <YYYY-MM-DD HH:mm>
> <content>
```

### 1.2 回复型评论（`eventType = 19`，`replyToCommentId` 非空）

```markdown
**<operatorName>** 回复 **<replyToCommentCreatorName>** · <YYYY-MM-DD HH:mm>
> <content>
```

### 1.3 已删除评论（`eventType = 20`）

`eventDetail.content` 有值但评论已被删除。显示时加删除线 + "已删除"标记：

```markdown
**<operatorName>** · <YYYY-MM-DD HH:mm>
> ~~<content>~~（已删除）
```

### 1.4 富文本内容渲染（HTML → markdown 保留格式）

`eventDetail.content` 是服务端返回的 **HTML 富文本字符串**。Agent 解析时**尽可能保留富文本语义**，转成 markdown 等效格式输出，**只有实在无法转换的元素才降级纯文本**。

#### 1.4.1 可保留的 HTML 元素 → markdown 映射

| HTML 元素 | markdown 输出 | 说明 |
|---------|-------------|------|
| `<br>` / `<br/>` | 换行 | 行内换行用引用块内的新行 |
| `<p>...</p>` | 段落 | 段间空行（引用块内用空 `>` 行分隔） |
| `<b>` / `<strong>` | `**文本**` | 粗体 |
| `<i>` / `<em>` | `*文本*` | 斜体 |
| `<s>` / `<del>` / `<strike>` | `~~文本~~` | 删除线 |
| `<a href="url">文本</a>` | `[文本](url)` | 链接保留可点击 |
| `<ul><li>` / `<ol><li>` | `- ` / `1. ` | 列表保留 |
| `<blockquote>` | 引用块内嵌套 `>>` | 引用保留 |
| `<code>` | `` `代码` `` | 行内代码 |
| `<pre>` | ``` ``` 代码块 ``` ``` | 代码块保留 |
| `<h1>`~`<h6>` | `#`~`######` | 标题保留 |
| `<img src="url" alt="alt">` | `![alt](url)` | 图片保留（markdown 可渲染） |

#### 1.4.2 POPO 富应用标签 → markdown 映射

POPO 在 HTML 中嵌入自定义标签（富应用），按下表转换，**保留可显示语义**：

| POPO 标签 | markdown 输出 | 说明 |
|---------|-------------|------|
| `[popoEmoji]{"text":"[大笑]","key":"1024"}[/popoEmoji]` | `[大笑]` | 表情无图，**必须用中括号包裹文字** `[表情文本]`，让用户感知此处原是表情（禁止丢掉或裸输出文字） |
| `[popoAt]{"text":"@张三","uid":"12345"}[/popoAt]` | `**@张三**` | @提及保留并加粗突出 |
| `[popoDoc]{"text":"文档名","docUrl":"https://..."}[/popoDoc]` | `[文档名](https://...)` | 云文档保留可点击链接 |
| `[popoFile]{"text":"文件名","fileId":"..."}[/popoFile]` | `📎 文件名` | 文件附件保留名+图标 |
| `[popoTask]{"text":"任务名","taskId":"123"}[/popoTask]` | `📋 任务名` | 任务引用保留名+图标 |

#### 1.4.3 降级规则（仅无法转换时）

- **未知 POPO 标签**（不在上表）：提取 `text` 字段纯文本，丢弃标签语法
- **未知 HTML 标签**：提取标签内纯文本，丢弃标签
- **嵌套结构异常 / 解析失败**：整段降级为纯文本（去标签），保证内容不丢
- **图片资源**（⛔ 禁止丢掉，必须保留占位标识）：
  - `<img src="url" alt="alt">` 且 URL 可访问 → 保留 `![alt](url)`（markdown 可渲染）
  - `<img>` URL 不可访问 / 无法渲染 / 解析失败 → 降级为 `[图片]` 占位（若 alt 非空用 `[图片：alt]`）
  - **绝对禁止**直接丢弃图片元素，必须保留 `[图片]` 或 `[图片：alt]` 让用户感知此处有图
- **表情**（⛔ 禁止裸输出文字）：`[popoEmoji]` 降级时**必须用中括号包裹** `[表情文本]`（如 `[大笑]`、`[微笑]`），让用户感知此处原是表情；禁止裸输出 `大笑` 或丢掉

> ⛔ **原则：能保留就保留，不能保留才降级；降级时必须保留占位标识，禁止丢内容。** 图片→`[图片]`、表情→`[表情文本]`，用户能感知原始富文本元素的存在。
> 转换后的内容整体放进 §1.1/1.2/1.3 的引用块 `>` 内，多行内容每行前加 `>`。

#### 1.4.4 转换示例

原始 HTML content：
```html
数据收集完成，已上传到 <popoDoc>周报.xlsx</popoDoc>，<b>请本周内 review</b><br>详情见 <a href="https://docs.example.com/r">评审文档</a>
```

转换后 markdown 输出（在引用块内）：
```markdown
> 数据收集完成，已上传到 [周报.xlsx](https://...)，**请本周内 review**
> 详情见 [评审文档](https://docs.example.com/r)
```

> 若 content 已是纯文本（无任何 HTML/POPO 标签），直接原样输出，不做额外转换。

### 1.5 示例

```markdown
### 💬 评论（共 5 条）

**Bob** · 2026-06-29 10:15
> 数据收集完成，已上传到附件

**Alice** 回复 **Bob** · 2026-06-29 10:20
> 收到，我开始撰写正文

**Carol** · 2026-06-29 11:00
> ~~这条评论已被删除~~（已删除）
```

> 多页时按"加载更多"模式续拉（与 `task_list` 一致）。

---

## 2. 日志渲染

`task_log_list` 返回日志类 EditRecord（`eventType` 为 1-99 中除 19、20 外的值）。

按 `timestamp` **倒序**展示（最新的在最上）。

### 2.1 时间格式化（强制）

> ⛔⛔ **绝对禁止原样输出时间戳，也绝对禁止心算日期。** 必须将 `timestamp`（EditRecord: 毫秒）用命令换算为 `YYYY-MM-DD HH:mm`。
> 换算命令见 [`task-detail-render.md` §5.0 标准换算命令](./task-detail-render.md#50-标准换算命令复制即用一次批量转多个)——把时间戳交给 `node`/`date` 输出字符串直接用，**不要**凭锚点手推。
> `timestamp`、`newDeadline`、`newStartTime` 等均为**毫秒**，直接传入（无需 ×1000）。

日期/时间字段（`newDeadline`、`prevStartTime` 等）根据对应 `*Format` 格式化：
- `*Format = 1`（仅日期）→ `YYYY/MM/DD`
- `*Format = 2`（日期+时间）→ `YYYY/MM/DD HH:mm`
- `*Format = 0` 或缺失 → 显示"未设置"

### 2.2 事件类型枚举与展示文案

根据 `eventType` 从 `eventDetail` 取字段拼接展示文本：

| eventType | 含义 | 展示文案 | 取值来源 |
|-----------|------|---------|---------|
| 1 | 创建待办 | 创建了待办 | — |
| 2 | 变更标题 | 将标题更改为 "{v}" | `newTitle` |
| 3 | 分配执行人 | 分配给 {v} | `participants[].name` 用"、"拼接 |
| 4 | 取消分配 | 取消分配给 {v} | `participants[].name` 用"、"拼接 |
| 8 | 添加截止时间 | 添加了截止时间 {v} | `newDeadline` + `newDeadlineFormat` |
| 9 | 变更截止时间 | 变更了截止时间 {v} | `newDeadline` + `newDeadlineFormat` |
| 10 | 删除截止时间 | 删除了截止时间 {v} | `prevDeadline` + `prevDeadlineFormat` |
| 17 | 完成待办 | 完成了待办 | `newFinishPercent`（显示完成度百分比） |
| 18 | 重建待办 | 重建了待办 | — |
| 19 | 添加评论 | （同 §1 评论渲染，不在此处重复） | `content` 等 |
| 20 | 删除评论 | （同 §1.3 删除评论渲染） | `content` |
| 25 | 取消验收 | 取消验收了待办 | — |
| 31 | 转让指派人 | 转让了指派人 → {v} | `name` |
| 32 | 添加开始时间 | 添加了开始时间 {v} | `newStartTime` + `newStartTimeFormat` |
| 33 | 变更开始时间 | 变更了开始时间 {v} | `newStartTime` + `newStartTimeFormat` |
| 34 | 删除开始时间 | 删除了开始时间 {v} | `prevStartTime` + `prevStartTimeFormat` |
| 35 | 添加关注人 | 添加 {v} 为关注人 | `participants[].name` 用"、"拼接 |
| 36 | 移除关注人 | 移除关注人 {v} | `participants[].name` 用"、"拼接 |
| 37 | 关注任务 | {v} 关注了任务 | `participants[].name` 用"、"拼接 |
| 38 | 取消关注 | {v} 取消关注了任务 | `participants[].name` 用"、"拼接 |
| 39 | 变更完成方式 | 变更任务完成方式为 {v} | `newCompleteCondition`：`"all"`→"所有人完成"、`"any_one"`→"任意一人完成" |
| 40 | 完成整个任务 | 完成了整个任务 | `newFinishPercent`（显示完成度百分比） |
| 41 | 完成自己的任务 | 完成了任务 | `newFinishPercent`（显示完成度百分比） |
| 42 | 关注人变执行人 | 将 {v} 变更为执行人 | `participants[].name` 用"、"拼接 |
| 43 | 重启整个任务 | 重启了整个任务 | — |
| 44 | 重启自己任务 | 重启了自己的任务 | — |
| 51 | 关联项目 | 将任务与 {v} 关联 | `projectName` |
| 52 | 解除项目关联 | 解除任务与 {v} 的关联 | `projectName` |
| 99 | 删除待办 | 删除了待办 | — |

其他未列出的 `eventType` 值统一展示为"操作了该任务"。

### 2.3 特殊值处理

- **participants 数组**：多个 name 用中文顿号"、"拼接，如 `张三、李四、王五`
- **newFinishPercent**：若 > 0 展示 `已完成 {percent}%`，否则仅展示文案
- **完成方式**：`"all"` → "所有人完成"，`"any_one"` / `"one"` → "任意一人完成"
- **eventDetail 字段缺失**：该项文案中不带替换值，仅输出核心动词（如"变更了截止时间"）
- **eventType 未知**：输出 `<operatorName> 操作了该任务`

### 2.4 通用渲染模板（含 AI 标识）

> ⛔ **渲染输出用 markdown 结构化格式**（粗体操作人 + 引用块文案），**不要**把整段塞进纯文本代码块。
> ✦ **AI 标识**：当 `aiOperated === true` 时，在操作时间后追加 `✦`（六角星，对齐客户端日志的星星标识），表示该操作由 AI 助手（MCP 入口）触发。`aiOperated === false` 或字段缺失时不加。

```markdown
# aiOperated === true（AI 操作）：
**<operatorName>** · <YYYY-MM-DD HH:mm> ✦
> <根据 eventType 拼接的文案>

# aiOperated === false 或缺失（人工操作）：
**<operatorName>** · <YYYY-MM-DD HH:mm>
> <根据 eventType 拼接的文案>
```

> 若一条日志的文案含多行（如 eventType=19 添加了评论且带内容），多行内容都放进同一个引用块 `>` 内。

### 2.5 示例

```markdown
### 📋 操作日志（共 12 条）

**Alice** · 2026-06-29 14:32 ✦
> 变更了截止时间 2026/06/30 18:00

**Bob** · 2026-06-29 11:05
> 添加了评论
> 附件已上传，请查收

**Carol** · 2026-06-29 10:00
> 关注了任务

**David** · 2026-06-28 09:00
> 将标题更改为 "Q3 季度总结报告"
```

> 上例中 Alice 的日志带 ✦ 表示由 AI 助手触发；Bob/Carol/David 无 ✦ 为人工操作。

---

## 3. 用户尝试发表评论 / 修改日志的拒绝模板

本 skill **不支持**评论写、日志写、日志删除等任何写操作。用户尝试时按统一模板拒绝：

### 3.1 用户："我想在这个任务下评论 / 加一条评论"

> 一期暂不支持在 popo-cli 中发表评论，请到 POPO 客户端任务面板内发表。已为你展示当前评论列表（如下）。

随即调 `task_comment_list` 展示现有评论（避免空回应）。

### 3.2 用户："把这条日志删了 / 改一下日志"

> 任务操作日志由系统自动记录，不支持手动修改或删除。

---

## 4. 边界与计数

- 评论数 / 日志数在 `task_detail` 的 `commentCount` / `logCount` 字段给出；详情底部以
  `💬 评论 N · 📋 日志 M` 一行汇总。
- 若用户问"评论数 / 日志数" → 直接读 `commentCount` / `logCount`，**不**调 `task_comment_list` / `task_log_list`（避免无谓拉取）。
- 评论列表与日志列表均支持分页（`pageSize` 默认 20，`pageToken` 续拉）。

---

## 5. 与客户端前端对齐说明

本规范与 POPO 客户端前端显示逻辑对齐了核心部分：

| 项目 | 客户端 | Skill 输出 | 对齐 |
|------|--------|-----------|:--:|
| eventType 文案模板 | 完整映射（§2.2） | 同 | ✅ |
| 时间格式化 | YYYY/MM/DD HH:mm 双格式 | 同 | ✅ |
| 评论回复判定 | `replyToCommentId` 非空 | 同 | ✅ |
| 删除评论 | 删除线 + "已删除"标签 | markdown 删除线 `~~`+ "已删除" | ✅ |
| 富文本渲染 | HTML（表情/粗体/链接/列表/云文档） | HTML→markdown 保留格式（§1.4），仅无法转换才降级 | ✅ 语义等效 |
| 参与者拼接 | "、"分隔 | 同 | ✅ |
| 完成方式翻译 | all→所有人 any_one→任意一人 | 同 | ✅ |
| 完成度进度圈 | SVG 圆环 | 百分比文本 | ⚠️ 图形无法等效 |
| AI 标识 | 操作时间后加星星 | `aiOperated=true` 时加 ✦ | ✅ |
| 渲染结构 | 富文本卡片 | markdown 结构化（粗体+引用块） | ✅ 语义等效 |

评论富文本（HTML）转 markdown 后，可显示的富文本元素（链接、粗体、列表、云文档、@提及、表情文字）均保留语义；仅图形资源（进度圈、表情图）降级为文本/占位，不影响信息理解。
