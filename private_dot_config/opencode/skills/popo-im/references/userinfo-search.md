# popo_userinfo_search

按姓名、昵称、邮箱搜索用户。支持两种场景：

- **独立使用**：用户想查找同事信息、搜索员工、查看组织架构内的人员
- **消息搜索辅助**：将人名解析为邮箱，供 `popo_message_search` 的 `contactList` 使用

> **⚠️ 必填参数提醒**：每次调用必须传 `query`、`type=2`、`page=0`，缺少任一参数会报错（如 `page must not be null`）。参数名是 `query` 不是 `keyword`。

## 命令

```bash
# 搜索员工（联系人 + 组织架构）— 标准用法
popo-cli popo userinfo_search query=张三 type=2 page=0 pageSize=10 searchRange=1 includeRobot=true
```

```bash
# 仅搜组织架构
popo-cli popo userinfo_search query=张三 type=2 page=0 pageSize=10 searchRange=3 includeRobot=true

# 仅搜联系人
popo-cli popo userinfo_search query=张三 type=2 page=0 pageSize=10 searchRange=2 includeRobot=true
```

## 请求参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `query` | String | 否 | - | 查询条件（搜索关键词） |
| `type` | Integer | **是** | - | 搜索入口，**固定传 `2`**（搜索用户） |
| `page` | Integer | **是** | - | 分页搜索开始页 |
| `pageSize` | Integer | 否 | - | 分页大小 |
| `searchRange` | Integer | 否 | - | `1` 搜联系人+组织架构（优先返回联系人），`2` 只搜联系人，`3` 只搜组织架构 |
| `includeRobot` | Boolean | **是** | - | 搜索结果是否包括机器人，**固定传 `true`**

> 完整参数列表中还有 `tid`、`includeService`、`sortType` 等参数，但在 popo-im 流程中一般只需上述参数。

## 响应参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `search_results` | SearchResult | 搜索结果 |
| `person_total` | Integer | 人员搜索结果总数 |
| `hasMore` | Integer | 是否有更多结果 |

### 关键提取路径

从 `search_results.person` 数组中提取每个结果：

| 路径 | 类型 | 说明 | 用途 |
|------|------|------|------|
| `content.uid` | String | 用户邮箱 | 作为 `popo_message_search` 的 `contactList`；作为 `message_send_team` 的 `atUids` |
| `content.showName` | String | 展示名称 | **群消息 @ 人时，优先用此字段值拼接 `@showName` 写入 message**。若此字段为空字符串或不存在，才用 `content.name` 兜底。禁止用用户输入的名字替代，即使看起来一样 |
| `content.name` | String | 用户姓名 | 向用户确认匹配结果；作为 `content.showName` 为空时的兜底值 |
| `content.nickname` | String | 昵称 | 辅助确认 |
| `content.company` | String | 公司 | 辅助确认同名用户 |

## 响应示例

```json
{
  "uid": "user@example.com",
  "sid": "search_xyz789",
  "search_results": {
    "person": [
      {
        "srid": "sr_p001",
        "highlight": "<em>张三</em>",
        "hit": "name",
        "content": {
          "uid": "zhangsan@example.com",
          "name": "张三",
          "nickname": "小张",
          "company": "网易",
          "showName": "张三",
          "email": "zhangsan@example.com"
        }
      }
    ],
    "group": [],
    "member": []
  },
  "person_total": 1,
  "hasMore": 0
}
```

## 使用要点

### 独立查询

当用户只是想查找某人信息时，直接将搜索结果格式化后回复在对话中：

- 展示 `content.name`、`content.uid`（邮箱）、`content.nickname`、`content.company`
- 多个匹配时列出前 3 个，告知用户总数


### 消息搜索辅助

作为消息搜索流程的 Step 2b 使用时：

- **命中 > 3 个时取前 3 个**（按相关性排序的前 3 个），告知用户选取了哪些
- 提取 `content.uid` 存入 `contactList` 供 `popo_message_search` 使用
