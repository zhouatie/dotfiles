# popo_team_search

按群名关键词搜索群组。支持两种场景：

- **独立使用**：用户想查找某个群聊、搜索群名
- **消息搜索辅助**：将群名解析为群 ID，供 `popo_message_search` 的 `sessionList` 使用

## 命令

```bash
# 搜索自己加入的群
popo-cli popo team_search query=项目讨论群 type=3 page=0 pageSize=10 onlySearchJoinedTid=true

# 搜索所有可见群（含未加入的）
popo-cli popo team_search query=项目讨论群 type=3 page=0 pageSize=10

# 按最近活跃排序
popo-cli popo team_search query=项目 type=3 page=0 pageSize=10 onlySearchJoinedTid=true sortType=1
```

## 请求参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `query` | String | 否 | - | 查询条件（搜索关键词） |
| `type` | Integer | **是** | - | 搜索入口，**固定传 `3`**（搜索群组） |
| `page` | Integer | **是** | - | 分页搜索开始页 |
| `pageSize` | Integer | 否 | - | 分页大小 |
| `onlySearchJoinedTid` | Boolean | 否 | `false` | 仅搜索自己所在的群组（推荐设为 `true`） |
| `sortType` | Integer | 否 | `0` | `0` 默认排序，`1` 按最近活跃，`2` 按群创建时间 |

> 完整参数列表中还有 `searchRange`、`memberIds`、`createTime` 等参数，但在 popo-im 流程中一般只需上述参数。

## 响应参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `search_results` | SearchResult | 搜索结果 |
| `group_total` | Integer | 群组搜索结果总数 |
| `hasMore` | Integer | 是否有更多结果 |

### 关键提取路径

从 `search_results.group` 数组中提取每个结果：

| 路径 | 类型 | 说明 | 用途 |
|------|------|------|------|
| `content.tid` | String | 群 ID | 作为 `popo_message_search` 的 `sessionList` |
| `content.tname` | String | 群名称 | 向用户确认匹配结果 |
| `content.lastMsgTime` | Long | 最近消息时间 | 辅助确认活跃群 |

## 响应示例

```json
{
  "uid": "user@example.com",
  "sid": "search_grp456",
  "search_results": {
    "person": [],
    "group": [
      {
        "srid": "sr_g001",
        "content": {
          "tid": "group_123",
          "tname": "项目讨论群",
          "type": 0,
          "highlight": "<em>项目讨论</em>群",
          "hit": "tname",
          "lastMsgTime": 1709999000000,
          "createTime": 1700000000000
        },
        "member": [
          {
            "name": "张三",
            "nickname": "小张",
            "uid": "zhangsan@example.com"
          }
        ]
      }
    ],
    "member": []
  },
  "group_total": 1,
  "hasMore": 0
}
```

## 使用要点

### 独立查询

当用户只是想查找群聊时，直接将搜索结果格式化后回复在对话中：

- 展示 `content.tname`（群名）、`content.tid`（群 ID）、`content.lastMsgTime`（最近活跃时间）
- 群中包含 `member` 列表时可展示部分成员
- 多个匹配时列出前 3 个，告知用户总数

### 消息搜索辅助

作为消息搜索流程的 Step 2a 使用时：

- **命中 > 3 个时取前 3 个**（按相关性排序的前 3 个），告知用户选取了哪些
- 提取 `content.tid` 存入 `sessionList` 供 `popo_message_search` 使用
- 推荐始终设置 `onlySearchJoinedTid=true`，确保搜索范围在用户自己的群内
