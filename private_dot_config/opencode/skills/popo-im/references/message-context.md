# popo_message_context

根据指定的会话和消息信息，查询消息的上下文内容（前后若干条消息）。

## 命令

```bash
# 单个会话的消息上下文
popo-cli popo message_context sessionMsg='[{"sessionId":"session_001","sessionType":1,"uuids":["msg_001","msg_002"],"msgTime":[1709000000000,1709000001000]}]'

# 多个会话（同一次调用）
popo-cli popo message_context sessionMsg='[{"sessionId":"session_001","sessionType":1,"uuids":["msg_001"],"msgTime":[1709000000000]},{"sessionId":"session_002","sessionType":1,"uuids":["msg_003"],"msgTime":[1709000002000]}]'

# 管道裁剪（推荐）
popo-cli popo message_context sessionMsg='[...]' | jq '.data.data.data.data | {msgContext: [.msgContext[]? | {sessionId, sessionType, contextInfo: [.contextInfo[]? | [.[]? | {nfrom, nto, context, timetag, uuid}]], contextIndices: [.contextIndices[]? | {msgId, index}]}]}'
```

> `sessionMsg` 是复杂嵌套结构，使用单引号包裹的 JSON 字符串传值。

## 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `sessionMsg` | List\<Element\> | **是** | 会话消息信息列表（JSON 字符串） |

### Element 结构

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `sessionId` | String | **是** | 会话 ID（来自 `popo_message_search` 返回的 `session_id`） |
| `sessionType` | Integer | **是** | 会话类型（来自 `popo_message_search` 返回的 `sessionType`） |
| `uuids` | List\<String\> | **是** | 消息 UUID 列表（来自 `popo_message_search` 返回的 `msg_id`） |
| `msgTime` | List\<Long\> | **是** | 消息时间戳列表（来自 `popo_message_search` 返回的 `t_msg`，与 `uuids` 一一对应） |

## 响应参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `msgContext` | List\<MsgContext\> | 消息上下文列表 |

### MsgContext 结构

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `sessionId` | String | 会话 ID |
| `sessionType` | Integer | 会话类型 |
| `contextInfo` | List\<List\<Msg\>\> | 上下文消息（二维列表，每组为一条搜索消息的前后上下文） |
| `contextIndices` | List\<ContextIndex\> | 上下文索引信息 |

### Msg 结构

> 管道裁剪（`jq`）后只保留标记 ✅ 的字段。

| 参数名 | 类型 | 说明 | 保留 |
|--------|------|------|------|
| `timetag` | Long | 消息时间戳 | ✅ 核心 |
| `nfrom` | String | 消息发送者 | ✅ 核心 |
| `nto` | String | 消息接收者 | ✅ 核心 |
| `context` | String | 消息内容 | ✅ 核心 |
| `uuid` | String | 消息 UUID | ✅ 流程辅助 |

### ContextIndex 结构

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `msgId` | String | 消息 ID |
| `index` | Integer | 在 contextInfo 中的索引位置 |

## 响应示例

```json
{
  "msgContext": [
    {
      "sessionId": "session_001",
      "sessionType": 1,
      "contextInfo": [
        [
          {
            "timetag": 1708999999000,
            "nfrom": "user_a@example.com",
            "nto": "group_123",
            "context": "上一条消息内容",
            "uuid": "uuid_000"
          },
          {
            "timetag": 1709000000000,
            "nfrom": "user_b@example.com",
            "nto": "group_123",
            "context": "目标消息内容",
            "uuid": "uuid_001"
          },
          {
            "timetag": 1709000001000,
            "nfrom": "user_c@example.com",
            "nto": "group_123",
            "context": "下一条消息内容",
            "uuid": "uuid_003"
          }
        ]
      ],
      "contextIndices": [
        {
          "msgId": "uuid_001",
          "index": 1
        }
      ]
    }
  ]
}
```

## 数据结构说明

- `contextInfo` 是二维列表：外层按搜索消息分组，内层是该消息的前后上下文
- `contextIndices` 将每条原始搜索消息映射到 `contextInfo` 中的索引位置
- 利用 `contextIndices[i].index` 可在 `contextInfo[i]` 中定位命中消息，其前后即为上下文
