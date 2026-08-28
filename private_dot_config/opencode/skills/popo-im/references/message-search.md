# popo_message_search

根据关键词和筛选条件搜索聊天消息。

## 命令

```bash
# 基本搜索
popo-cli popo message_search query=进度 type=1 page=0 pageSize=20 msgType=0

# 指定联系人和会话
popo-cli popo message_search query=搜索关键词 type=1 page=0 pageSize=20 msgType=0 contactList='["zhangsan@example.com"]' sessionList='["group_123"]'

# 指定时间范围（毫秒时间戳）
popo-cli popo message_search query=进度 type=1 page=0 pageSize=20 msgType=0 timeStart=1709000000000 timeEnd=1710000000000

# 多个联系人/会话用 JSON 数组格式
popo-cli popo message_search query=进度 type=1 page=0 pageSize=20 msgType=0 contactList='["a@example.com","b@example.com"]' sessionList='["group_1","group_2"]'

# 管道裁剪（推荐）
popo-cli popo message_search query=进度 type=1 page=0 pageSize=20 msgType=0 | jq '.data.data.data.data | {sid, page, has_more, result_list: [.result_list[]? | {nfrom, nto, content, t_msg, msg_id, session_id, sessionType, sessionName, memberName}]}'
```

## 请求参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `sid` | String | 否 | - | 查询 ID，若为空则新建 |
| `query` | String | 否 | - | 查询条件（搜索关键词） |
| `type` | Integer | **是** | - | 搜索入口 |
| `page` | Integer | **是** | - | 分页搜索开始页 |
| `pageSize` | Integer | 否 | `20` | 分页大小 |
| `subLength` | Integer | 否 | - | 截断长度 |
| `timeStart` | Long | 否 | - | 开始时间（毫秒时间戳） |
| `timeEnd` | Long | 否 | - | 结束时间（毫秒时间戳） |
| `msgType` | Integer | **是** | - | 消息类型 |
| `contactList` | List\<String\> | 否 | - | 联系人邮箱列表（JSON 数组格式） |
| `sessionList` | List\<String\> | 否 | - | 会话 ID 列表（JSON 数组格式） |
| `oldSid` | String | 否 | - | 旧的搜索 ID |
| `searchRange` | Integer | 否 | - | 搜索范围：`0` 不包含已退群，`1` 包含已退群 |
| `atMembers` | List\<String\> | 否 | - | 消息的 @成员列表 |
| `sortType` | String | 否 | `DEFAULT` | 消息排序方式 |
| `pinType` | Integer | 否 | `0` | Pin 筛选：`0` 不启用，`1` 我 Pin，`2` 所有 Pin |

## 响应参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `uid` | String | 用户 ID |
| `sid` | String | 搜索 ID |
| `t_when` | Long | 搜索时间戳 |
| `page` | Integer | 当前页码 |
| `has_more` | Boolean | 是否有更多结果 |
| `result_list` | List\<MessageElement\> | 消息结果列表 |

### MessageElement 结构

> 管道裁剪（`jq`）后只保留标记 ✅ 的字段。

| 参数名 | 类型 | 说明 | 保留 |
|--------|------|------|------|
| `srid` | String | 搜索结果 ID | |
| `msg_id` | String | 消息 ID | ✅ 流程辅助 |
| `msg_type` | String | 消息类型 | |
| `t_msg` | Long | 消息时间戳 | ✅ 核心 |
| `nfrom` | String | 消息发送者 | ✅ 核心 |
| `nto` | String | 消息接收者 | ✅ 核心 |
| `session_id` | String | 会话 ID | ✅ 流程辅助 |
| `sessionType` | Integer | 会话类型 | ✅ 流程辅助 |
| `content` | String | 消息内容 | ✅ 核心 |
| `empType` | Integer | 在职类型 | |
| `pic` | String | 头像 | |
| `state` | Integer | 状态 | |
| `teamState` | Integer | 群状态 | |
| `sessionName` | String | 会话名称 | ✅ 流程辅助 |
| `memberName` | String | 成员名称 | ✅ 流程辅助 |
| `msgToken` | String | 消息 Token | |
| `sourceMsg` | String | 原消息体 | |
| `pin_uid` | String | Pin 操作者 UID | |
| `pinUsername` | String | Pin 操作者用户名 | |

## 响应示例

```json
{
  "uid": "user@example.com",
  "sid": "search_abc123",
  "t_when": 1710000000000,
  "page": 0,
  "has_more": true,
  "result_list": [
    {
      "srid": "sr_001",
      "msg_id": "msg_001",
      "msg_type": "text",
      "t_msg": 1709000000000,
      "nfrom": "sender@example.com",
      "nto": "group_123",
      "session_id": "session_001",
      "sessionType": 1,
      "content": "项目进度已更新",
      "sessionName": "项目讨论群",
      "memberName": "张三"
    }
  ]
}
```

## 翻页

- 记录首次返回的 `sid`，后续翻页时传入
- 若 `has_more` 为 true，`page` + 1 继续搜索
- **最多取 3 页**（共 60 条），超过后告知用户并询问是否继续
