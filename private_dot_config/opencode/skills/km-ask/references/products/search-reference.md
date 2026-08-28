# 搜索 API 详细参考

> 搜索域的详细参考文档。包含响应结构详情、工作流示例、错误处理和消歧规则。
>
> **核心文档**：请求参数、意图分类、参数提取、展示约束和格式化模板见 [search.md](search.md)。

> ⚠️ **执行约束**：本文档所有操作必须通过 `popo-cli` 命令执行，禁止直接调用 API 端点。

## 响应结构

### 成功响应

```json
{
    "status": 200,
    "message": "success",
    "data": {
        "resourceItems": [
            {
                "resourceType": "blog",
                "resourceId": 123456,
                "title": "标题中 <em>高亮</em> 关键词",
                "summary": "摘要中 <em>高亮</em> 关键词",
                "coverUrl": "https://km.fp.ps.netease.com/file/xxx.jpg",
                "url": "https://km.netease.com/article/123456",
                "authorInfo": {
                    "id": 10001,
                    "name": "张三",
                    "nickname": "小张(张三)",
                    "email": "zhangsan@corp.netease.com",
                    "imageUrl": "https://km.fp.ps.netease.com/avatar/xxx.jpg",
                    "deptName": "技术中心/平台开发部"
                },
                "updatedAt": "2025-03-15T10:30:00+08:00",
                "createdAt": "2025-03-01T09:00:00+08:00",
                "tags": [
                    {"id": 1001, "tagName": "标签名", "tagType": "USER_TAG"}
                ],
                "statistic": {
                    "pv": 1520,
                    "uv": 680,
                    "likeNum": 45,
                    "collectNum": 23,
                    "commentNum": 8
                }
            }
        ],
        "offset": 5,
        "hasMore": true
    }
}
```

> **展示字段提示**：上述 JSON 为 API 完整返回结构。向用户展示时，**仅使用**以下六个字段：`title`、`authorInfo.nickname`、`url`、`createdAt`、`updatedAt`、`summary`。其余字段仅供内部逻辑使用。

### 响应字段参考

#### data 对象

| 字段 | 类型 | 描述 |
|------|------|------|
| resourceItems | Array | 资源对象列表 |
| offset | Integer | 下一页偏移量（传入下次请求的 `offset` 参数） |
| hasMore | Boolean | `true` 表示还有更多结果 |

#### resourceItems[] 对象

| 字段 | 类型 | 描述 |
|------|------|------|
| resourceType | String | `blog`/`attachment`/`page`/`video`/`topic`/`link` |
| resourceId | Long | 资源 ID |
| title | String | 标题；关键词用 `<em>` 标签包裹 |
| summary | String | 摘要；关键词用 `<em>` 标签包裹 |
| coverUrl | String | 封面图 URL |
| url | String | 资源直达链接 |
| authorInfo | Object | 作者详情（见下方 authorInfo 对象） |
| updatedAt | String | 最后更新时间，ISO 8601 格式 |
| createdAt | String | 资源创建/发布时间，ISO 8601 格式 |
| tags | Array | 标签列表 |
| statistic | Object | 浏览/点赞/收藏/评论计数（见下方说明） |

> **必须展示字段**（共 6 个）：`title`、`authorInfo.nickname`、`url`、`createdAt`、`updatedAt`、`summary`。
> 其余字段（resourceType、resourceId、coverUrl、tags、statistic 等）仅供内部逻辑使用，**不向用户展示**。

#### authorInfo 对象

| 字段 | 类型 | 描述 |
|------|------|------|
| id | Long | 用户 ID |
| name | String | 显示名 |
| nickname | String | 作者昵称。格式：若用户设置了昵称则为 `昵称(真实姓名)`（如 `小张(张三)`）；未设置昵称则等于真实姓名（如 `张三`） |
| email | String | 邮箱 |
| imageUrl | String | 头像 URL |
| deptName | String | 部门名称 |

### 错误响应

| 状态码 | 消息 | 原因 |
|--------|------|------|
| 400 | "至少需要一个搜索条件" | 未提供任何搜索条件 |
| 400 | "用户未找到" | 邮箱不匹配任何 KM 用户 |
| 401 | "未授权" | 访问令牌无效或已过期 |

## 排序规则

| 场景 | 排序方式 |
|------|----------|
| 提供了 `query` | 相关度降序，然后创建时间降序 |
| 未提供 `query`（仅筛选） | 创建时间降序 |

## 核心工作流

```bash
# 关键词搜索
popo-cli km search_resource query="微服务架构" offset=0 size=5

# 组合搜索（关键词 + 作者 + 时间 + 类型）
popo-cli km search_resource query="用户增长" author=张三 resourceType=blog dateFrom=2025-01-01 dateTo=2025-06-30 offset=0 size=10
```

## 执行

参数提取完成后，通过 `popo-cli` 执行：

```bash
popo-cli km search_resource query="..." author="..." resourceType=blog dateFrom=2026-01-01 dateTo=2026-03-23 offset=0 size=5
```

`query`、`author`、`resourceType`、`dateFrom`、`dateTo` 中至少提供一个。

若参数提取失败或有歧义，回退使用用户完整输入作为 `query`。

## 消歧

搜索结果为空时，展示输出中的建议信息。

完全无法提取参数时，询问："请输入搜索内容，可以提供关键词、作者姓名或时间范围。"

时间表达模糊时（如仅说"最近"），默认取 30 天并告知用户。

## 上下文链表

| 操作 | 从响应中提取 | 用于 |
|------|-------------|------|
| 搜索 | `data.resourceItems[].url` | 为用户提供直达链接 |
| 搜索 | `data.resourceItems[].resourceId` | 后续资源详情获取 |
| 搜索 | `data.offset` | 下一页请求的 offset |
| 搜索 | `data.hasMore` | 分页继续判断 |

## 注意事项

- 仅搜索 KM 资源（不含 Salon 媒体/计划类型）
- 结果按搜索者邮箱的访问权限进行过滤
- 同名作者返回所有匹配作者的资源
- 不存在的作者姓名返回空结果（不报错）
- 标题/摘要中的 `<em>` 标签在渲染时需要去除或处理
