# 消息搜索 — 执行流程

> 开始搜索前请先阅读 SKILL.md 中的 NEVER DO 和消息搜索权限边界。

## Step 1: 解析用户查询

从用户的自然语言中提取：

- **搜索关键词**：用户想搜索的消息内容关键字
- **实体引用**：可能是群名或人名
- **时间范围**：提到的日期或时间段 → 转为毫秒级 Unix 时间戳
- **搜索范围**：特定群聊、特定人、还是全局搜索

**首先判断搜索主体**：用户查询的是不是自己参与的消息？
- 查询涉及"我和某人"、"某人在某群说的"、"我最近的消息" → 合法，继续
- 查询涉及"某人A和某人B之间" 且当前用户不在其中 → 超出权限边界，按 SKILL.md 中的模板回复，**终止流程**

判断实体类型：
- 提到**群名** → 需要 Step 2a 解析群 ID
- 提到**人名** → 需要 Step 2b 解析用户邮箱
- 没有特定实体 → 直接跳到 Step 3

## Step 2: 解析实体

将用户提到的群名/人名转换为系统 ID。如果同时涉及群名和人名，**并行执行** 2a 和 2b。

#### Step 2a: 群名 → 群 ID

使用 `popo_team_search`（详见 `references/team-search.md`）：

```bash
popo-cli popo team_search query=项目讨论群 type=3 page=0 pageSize=10 onlySearchJoinedTid=true
```

- 从 `search_results.group` 提取 `content.tid`（群 ID）和 `content.tname`（群名）
- **命中 > 3 个时取前 3 个**
- 存入 `sessionList` 供 Step 3 使用

#### Step 2b: 人名 → 用户邮箱

使用 `popo_userinfo_search`（详见 `references/userinfo-search.md`）：

```bash
popo-cli popo userinfo_search query=张三 type=2 page=0 pageSize=10 searchRange=1
```

- 从 `search_results.person` 提取 `content.uid`（邮箱）和 `content.name`（姓名）
- **命中 > 3 个时取前 3 个**
- 存入 `contactList` 供 Step 3 使用

## Step 3: 搜索消息

使用 `popo_message_search`（详见 `references/message-search.md`）：

```bash
popo-cli popo message_search query=搜索关键词 type=1 page=0 pageSize=20 msgType=0 contactList='["zhangsan@example.com"]' sessionList='["group_123"]' timeStart=1709000000000 timeEnd=1710000000000
```

> 多个联系人或会话用 JSON 数组格式：`contactList='["a@example.com","b@example.com"]'`

**数据裁剪**（必须执行）：返回结果通过 `jq` 过滤冗余字段：

```bash
popo-cli popo message_search query=关键词 type=1 page=0 pageSize=20 | jq '.data.data.data.data | {sid, page, has_more, result_list: [.result_list[]? | {nfrom, nto, content, t_msg, msg_id, session_id, sessionType, sessionName, memberName}]}'
```

裁剪后保留字段见 `references/message-search.md`。

- 记录 `sid`，若 `has_more` 为 true，可继续翻页（最多取 3 页共 60 条）

## Step 4: 获取消息上下文

将搜索到的消息按 `session_id` 分组，使用 `popo_message_context`（详见 `references/message-context.md`）批量查询上下文：

```bash
popo-cli popo message_context sessionMsg='[{"sessionId":"session_001","sessionType":1,"uuids":["msg_001","msg_002"],"msgTime":[1709000000000,1709000001000]}]'
```

> `sessionMsg` 是复杂嵌套结构，使用单引号包裹的 JSON 字符串传值。

**数据裁剪**（必须执行）：

```bash
popo-cli popo message_context sessionMsg='[...]' | jq '.data.data.data.data | {msgContext: [.msgContext[]? | {sessionId, sessionType, contextInfo: [.contextInfo[]? | [.[]? | {nfrom, nto, context, timetag, uuid}]], contextIndices: [.contextIndices[]? | {msgId, index}]}]}'
```

裁剪后保留字段见 `references/message-context.md`。

- `contextInfo` 是二维列表 — 每个内层列表是一条搜索消息的前后上下文
- `contextIndices` 将每条原始消息映射到 `contextInfo` 中的索引位置

## Step 5: 格式化输出

将搜索结果按以下格式直接回复在对话中。

### 输出格式

```markdown
# POPO 消息搜索结果

**搜索关键词**：<keyword>
**搜索时间**：<YYYY-MM-DD HH:mm:ss>
**命中消息数**：<N> 条，共 <M> 个会话

---

## 会话：<会话名称>

| 时间 | 发送方 | 内容 | 上下文 |
|------|--------|------|--------|
| YYYY-MM-DD HH:mm:ss | 张三 | 命中的消息内容 | [HH:mm] 李四: 上文...<br>**[HH:mm] 张三: 命中内容** ← 命中<br>[HH:mm] 王五: 下文... |
```

### 格式说明

- **每个会话一张表格**，会话之间用 `---` 分隔
- **时间**：格式 `YYYY-MM-DD HH:mm:ss`，会话内按时间倒序
- **发送方**：使用 `nfrom` 中的邮箱地址展示；如有可用的用户名信息则优先展示人名
- **上下文**：前后 2-3 条消息用 `<br>` 换行拼接；命中消息加粗并标注 `← 命中`
- 群聊无需单独展示接收方；单聊在"内容"列末尾注明 `→ <对方姓名>`

### 标准回复模板

按上述格式组织后直接回复。回复开头包含摘要统计：

```
共找到 <N> 条消息，分布在 <M> 个会话中。
```

后接各会话的消息表格。

### 组合调用输出格式

被其他 skill 组合调用时，在回复开头加上交接标识：

```
[popo-im → 返回给调用方]
📊 共找到 <N> 条消息，分布在 <M> 个会话中

已完成消息采集，请继续执行你的主流程。
```

后接标准格式的消息表格。

## 上下文传递表

| 操作 | 从返回中提取 | 用于 |
|------|-------------|------|
| `popo_team_search` | `content.tid`（群 ID） | `popo_message_search` 的 `sessionList` |
| `popo_userinfo_search` | `content.uid`（邮箱） | `popo_message_search` 的 `contactList` |
| `popo_message_search` | `msg_id`, `t_msg`, `session_id`, `sessionType` | `popo_message_context` 的 `sessionMsg` |

## 流程决策图

```
用户说"帮我查下张三在项目群里关于进度的消息"
    │
    ├─ 解析意图：
    │   关键词 = "进度"
    │   群名 = "项目群" → Step 2a
    │   人名 = "张三" → Step 2b
    │
    ├─ 并行解析实体：
    │   ├─ popo_team_search("项目群") → 取 top 3 群 ID → sessionList
    │   └─ popo_userinfo_search("张三") → 取 top 3 邮箱 → contactList
    │
    ├─ 搜索消息：popo_message_search(query="进度", sessionList=[...], contactList=[...])
    │   ├─ 有结果 → 继续
    │   └─ 无结果 → 告知用户，建议调整关键词或时间范围
    │
    ├─ 获取上下文：popo_message_context(按 session 分组的消息 ID 和时间戳)
    │
    └─ 格式化输出 → 直接回复
```

## 边界情况

- **无搜索结果**：告知用户未找到匹配消息，建议扩大关键词范围或调整时间区间
- **实体解析无结果**：群名或人名无法解析时，告知用户并改用纯关键词搜索（不传 `sessionList` / `contactList`）
- **实体匹配过多（> 3）**：取前 3 个，告知用户选取了哪些实体，并提示存在更多匹配
- **翻页**：3 页后仍有更多结果，告知用户并询问是否继续获取

## 错误处理

1. `popo-cli` 返回错误时，查看返回的错误信息
2. 禁止自行尝试替代方案，将错误信息报告给用户
3. 若搜索超时或失败，建议用户缩小搜索范围（缩短时间区间、添加更具体的关键词）
