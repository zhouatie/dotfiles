# 搜索 API 参考

> 搜索域的核心 API 参考。当意图路由至搜索域时加载本文件。
> ⚠️ **执行约束**：所有操作必须通过 `popo-cli` 命令执行，禁止直接调用 API 端点。

## popo-cli km search_resource

多条件 KM 资源搜索。通过 `popo-cli km search_resource` 命令执行。

> 底层端点（仅供参考）：`POST /open-api/v1/portal/search/km-resource`。认证由 popo-cli 自动处理，无需手动配置。

## 请求参数

通过 `popo-cli km search_resource key=value` 形式传递：

| 参数 | 类型 | 必填 | 默认值 | 描述 |
|------|------|------|--------|------|
| query | String | 否 | - | 搜索关键词；匹配标题（高权重）和正文；命中词用 `<em>` 标签高亮 |
| author | String | 否 | - | 作者姓名；精确匹配（返回所有同名作者的资源） |
| resourceType | String | 否 | - | 资源类型筛选：`blog`、`attachment`、`page`、`video`、`topic`、`link` |
| dateFrom | String | 否 | - | 起始日期（含），格式 `yyyy-MM-dd` |
| dateTo | String | 否 | - | 截止日期（含），格式 `yyyy-MM-dd` |
| offset | Integer | 否 | 0 | 分页偏移量 |
| size | Integer | 否 | 5 | 每页数量，最大 50 |

### 校验规则

1. `query`、`author`、`resourceType`、`dateFrom`、`dateTo` 中至少提供一个
2. `size` 不得超过 50
3. 所有筛选条件以 AND 逻辑组合

## 资源类型映射

| 用户表述 | API 值 | 描述 |
|----------|--------|------|
| 文章、KM 文章、博客、博文 | `blog` | 博客文章 |
| 附件、文件、资料 | `attachment` | 附件资源 |
| Wiki、百科、Wiki 页面 | `page` | Wiki 页面 |
| 视频、录像 | `video` | 视频资源 |
| 专题、合集 | `topic` | 专题合集 |
| 链接、外部链接 | `link` | 链接资源 |

## 意图分类

当用户输入被路由到搜索域时，分类为以下意图类型之一：

| 意图 | 触发条件 | 示例 |
|------|----------|------|
| `keyword_search` | 仅关键词，无作者/时间 | "搜索 SDD 相关 KM 文章" |
| `author_search` | 包含作者姓名 | "张三发布的文章" |
| `time_search` | 包含时间表达 | "上周的 SDD 文章" |
| `author_time_search` | 同时包含作者和时间 | "张三最近 30 天的项目文档" |
| `type_search` | 指定资源类型 | "SDD 相关视频" |

## 参数提取

从自然语言输入中提取以下参数：

| 参数 | 提取模式 | 映射到 popo-cli 参数 |
|------|----------|----------------------|
| 关键词 | 去除意图动词、作者、时间、类型后的核心名词/短语 | `query` |
| 作者 | 人名实体："{姓名}发布的"、"{姓名}写的"、"{姓名}的" | `author` |
| 时间范围 | 见下方时间表达解析规则 | `dateFrom` / `dateTo` |
| 资源类型 | 见上方资源类型映射 | `resourceType` |

### 时间表达解析

| 用户表述 | 转换规则 |
|----------|----------|
| "最近N天" / "近N天" | dateFrom = 今天 - N，dateTo = 今天 |
| "上周" / "上个月" / "最近 30 天" | N = 7 / 30 / 30 |
| "N月" | dateFrom = 当年 N 月第一天，dateTo = N 月最后一天 |
| "今年" | dateFrom = 当年 1 月 1 日，dateTo = 今天 |
| "上月" | dateFrom = 上月第一天，dateTo = 上月最后一天 |
| "从 A 到 B" | dateFrom = A，dateTo = B |

所有日期使用 `yyyy-MM-dd` 格式。

## 展示约束

搜索结果向用户展示时，**必须且仅展示**以下六个字段，**按固定顺序展示，不可调换、不可合并、不可省略**：

| 顺序 | 展示名 | 数据来源 | 说明 |
|------|--------|----------|------|
| 1 | 标题 | `title` | 去除 `<em>` 标签后的纯文本 |
| 2 | 作者 | `authorInfo.nickname` | 格式：`昵称(真实姓名)` 或 `真实姓名` |
| 3 | 阅读地址 | `url` | 资源直达链接 |
| 4 | 发布时间 | `createdAt` | 转为友好时间格式展示 |
| 5 | 更新时间 | `updatedAt` | 转为友好时间格式展示 |
| 6 | 摘要 | `summary` | 去除 `<em>` 标签后的纯文本 |

> **禁止展示**以下字段：`coverUrl`、`tags`、`resourceId`、`resourceType`、`statistic`（含 pv/uv/likeNum 等）、`authorInfo.email`、`authorInfo.imageUrl`、`authorInfo.deptName`、`authorInfo.id`、`authorInfo.name`。

## 结果格式化

> ⚠️ **强制换行规则**：每个字段**必须独占一行**输出。**严禁**将多个字段写在同一行。**严禁**使用 `|`、`/`、空格或任何分隔符将字段拼接在一行内。违反此规则的输出格式一律视为错误。

将 `popo-cli` 返回的 JSON 按以下**固定模板逐行输出**，每个字段一行，顺序固定，不得调换、合并或省略：

```
1. 标题: {title（纯文本）}
   作者: {nickname}
   链接: {url}
   发布时间: {createdAt}
   更新时间: {updatedAt}
   摘要: {summary（纯文本）}

2. 标题: {title（纯文本）}
   作者: {nickname}
   链接: {url}
   发布时间: {createdAt}
   更新时间: {updatedAt}
   摘要: {summary（纯文本）}

{继续编号，直到当前页所有结果展示完毕}

{如果 hasMore: "回复"更多"查看下一页。"}
```

> **正确示例**（每个字段独占一行）：
> ```
> 1. 标题: 微服务架构设计实践
>    作者: 小张(张三)
>    链接: https://km.netease.com/blog/123456
>    发布时间: 2025-06-01
>    更新时间: 2025-06-15
>    摘要: 本文介绍了微服务架构的核心设计原则...
> ```
>
> **错误示例**（多字段挤在一行，**严禁**）：
> ```
> 标题: 微服务架构设计实践 作者: 小张(张三) 链接: https://km.netease.com/blog/123456 发布时间: 2025-06-01 更新时间: 2025-06-15 摘要: 本文介绍了...
> ```

当用户说"更多"时，使用上次响应中的 `offset` 和相同参数重新调用 `popo-cli km search_resource`。

## 分页

采用 offset/size 分页模型。响应中 `offset` 为下一页偏移量，`hasMore` 为是否还有更多结果。首次请求传 `offset=0`，翻页时传入上次响应的 `offset` 值。

## 详细参考

响应字段详情、错误码、工作流示例、消歧规则等见 [search-reference.md](search-reference.md)。
