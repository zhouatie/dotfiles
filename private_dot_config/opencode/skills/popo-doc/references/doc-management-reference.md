# 文档管理工具参考

所有操作通过 Bash 执行 `popo-cli popo <工具名> key=value` 命令完成。

## 调用前检查

- 团队空间文档必须传 `teamSpaceId`；只有 URL 时先用 `popo_doc_get_folder_path` 提取。
- 只有 URL 含 `/team/pc/` 或明确来自团队空间时才获取并传 `teamSpaceId`。
- 删除类操作必须先与用户二次确认。
- 禁止手动构造 `docId` / `folderId` / `teamSpaceId`；必须从搜索、详情、目录或创建接口返回中提取。
- 创建 docType=1 的初始内容时，`content` 只能用自定义 HTML，格式见 [popo-doc-content-format.md](./popo-doc-content-format.md)；docType=4 使用标准 Markdown。

---

## popo_doc_create_doc

创建文档、文件夹、Markdown、表格或多维表。

### 参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `docType` | Integer | 是 | 文档类型: 0-文件夹, 1-POPO文档, 2-POPO表格, 4-在线Markdown, 9-多维表 |
| `title` | String | 是 | 文档标题 |
| `parentId` | String | 否 | 父文件夹ID，默认根目录 |
| `teamSpaceId` | String | 否 | 团队空间ID，传递则创建在团队空间 |
| `content` | String | 否 | 文档初始化内容，仅用于可编辑文档：docType=1 使用自定义 HTML，格式见 [popo-doc-content-format.md](./popo-doc-content-format.md)；docType=4 使用标准 Markdown。**该参数为普通字符串，不支持 `=@file:` 语法**（误用会把文件路径当字面内容写入文档）。多行/含特殊字符的内容（尤其 Windows）请用两步法：先建空文档（不传 `content`），再用 `doc_update_doc` 的 `md.replace_page`（docType=4）/ `doc.replace_page`（docType=1）+ `=@file:` 写入，详见 [workflows.md 工作流 1b](./workflows.md) |

### 返回值

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `docId` | String | 文档ID |
| `url` | String | 文档访问URL |
| `type` | Integer | 文档类型（同 docType：0/1/2/4/9） |
| `teamSpaceId` | String | 团队空间ID(仅团队空间文档返回) |

### 示例

```
popo-cli popo doc_create_doc docType=1 title=项目周报 parentId=abc123

popo-cli popo doc_create_doc docType=1 title=项目周报 content="<h2>本周总结</h2><p>完成事项...</p>"

popo-cli popo doc_create_doc docType=0 title=项目资料

popo-cli popo doc_create_doc docType=2 title=数据统计 teamSpaceId=ts_xxx

popo-cli popo doc_create_doc docType=4 title=接口说明 content="# 接口说明\n\n## 概览\n\n- 支持创建和更新。"
```

### 两步法：创建带多行内容的 POPO 文档（docType=1，Windows 推荐）

`content` 不支持 `=@file:`，多行 HTML 在 Windows 上直接内联易失败。改用两步法。**必须用 node 生成 JSON 临时文件**（PowerShell `ConvertTo-Json` 会把中文弯引号规范化成普通双引号导致坏 JSON）：

```powershell
# Step 1: 创建空 POPO 文档
popo-cli popo doc_create_doc docType=1 title="项目周报" parentId=<PARENT_ID> teamSpaceId=<TEAM_SPACE_ID>
# 返回 docId=<DOC_ID>

# Step 2: 用 node 生成 command JSON 临时文件（JSON.stringify 正确转义所有 Unicode 字符）
$genScript = @'
const fs = require("fs"); const path = require("path");
const html = [
  "<h2>本周总结</h2>",
  "<p>完成事项...</p>",
  '<doc-li list-id="l1" list-type="unordered">需求评审</doc-li>'
].join("\n");
const tmp = path.join(require("os").tmpdir(), "popo_doc_cmd.json");
fs.writeFileSync(tmp, JSON.stringify({type:"doc.replace_page",content:html}), {encoding:"utf8"});
console.log(tmp);
'@
$cmdTmpFile = node -e $genScript

# Step 3: 用 =@file: 传 command 参数
popo-cli popo doc_update_doc docId=<DOC_ID> teamSpaceId=<TEAM_SPACE_ID> command="@file:$cmdTmpFile"
Remove-Item -Path $cmdTmpFile -ErrorAction SilentlyContinue
```

> HTML 内容格式必须遵循 [popo-doc-content-format.md](./popo-doc-content-format.md)，禁止 Markdown。

### 两步法：创建带多行内容的 Markdown 文档（Windows 推荐）

`content` 不支持 `=@file:`，多行 Markdown 在 Windows 上直接内联易失败。改用两步法。**必须用 node 生成 JSON 临时文件**（PowerShell `ConvertTo-Json` 会把中文弯引号规范化成普通双引号导致坏 JSON）：

```powershell
# Step 1: 创建空 Markdown 文档
popo-cli popo doc_create_doc docType=4 title="AI应用总结" parentId=<PARENT_ID> teamSpaceId=<TEAM_SPACE_ID>
# 返回 docId=<DOC_ID>

# Step 2: 用 node 生成 command JSON 临时文件（JSON.stringify 正确转义所有 Unicode 字符）
$genScript = @'
const fs = require("fs"); const path = require("path");
const md = [
  "# AI应用总结",
  "",
  "## 一、概述",
  "正文内容..."
].join("\n");
const tmp = path.join(require("os").tmpdir(), "popo_md_cmd.json");
fs.writeFileSync(tmp, JSON.stringify({type:"md.replace_page",content:md}), {encoding:"utf8"});
console.log(tmp);
'@
$cmdTmpFile = node -e $genScript

# Step 3: 用 =@file: 传 command 参数
popo-cli popo doc_update_doc docId=<DOC_ID> teamSpaceId=<TEAM_SPACE_ID> command="@file:$cmdTmpFile"
Remove-Item -Path $cmdTmpFile -ErrorAction SilentlyContinue
```

---

## popo_doc_delete_doc

删除文档、文件夹、表格或多维表。

### 参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `docId` | String | 是 | 文档ID |
| `teamSpaceId` | String | 否 | 团队空间ID，传递则删除团队空间文档，不传则删除云空间文档 |

### 返回值

无返回体 (成功返回 status=1)。

### 示例

```
popo-cli popo doc_delete_doc docId=abc123

popo-cli popo doc_delete_doc docId=page_xxx teamSpaceId=ts_xxx
```

---

## popo_doc_search_doc

文档语义检索，支持搜索文档、表格、多维表，支持时间、权限等多维表语义，直接传入用户的原始 query 即可，不需要做 query 改写。

### 参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `query` | String | 是 | 检索查询(语义搜索) |

### 返回值 (数组)

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `docId` | String | 文档ID(团队空间为 pageId) |
| `title` | String | 文档标题 |
| `url` | String | 文档访问URL |
| `type` | Integer | 文档类型 |

> 返回值不含 `teamSpaceId`。如搜到团队空间文档（URL 含 `/team/`），需通过 `popo_doc_get_folder_path` 传入该 URL 来获取 `teamSpaceId`。

### 示例

```
popo-cli popo doc_search_doc query=季度总结报告
```

---

## popo_doc_get_doc_detail

获取文档详情，包含元信息和内容(POPO 文档返回自定义 HTML；Markdown 文档返回 Markdown 内容，具体以接口返回为准)。团队空间文档必须先通过 `popo_doc_get_folder_path` 从原始 `/team/pc/.../pageDetail/...` URL 解析 `teamSpaceId`，再用 `docId + teamSpaceId` 调用；不要只传 pageDetail 中的资源 ID。

### 参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `docId` | String | 条件必填 | 文档ID；云空间可直接传 docId；团队空间必须传 URL 中 `pageDetail/` 后的 pageId |
| `teamSpaceId` | String | 团队空间必填 | 团队空间ID；先用 `popo_doc_get_folder_path url=<原始URL>` 获取 |
| `docIdOrUrl` | String | 条件必填 | 仅云空间兼容参数，可传云空间 docId 或 URL；与 `docId` 二选一。团队空间不要只传 URL/资源ID，必须拆成 `docId + teamSpaceId` |

### 返回值

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `title` | String | 文档标题 |
| `creatorName` | String | 创建者姓名 |
| `createdAt` | String | 创建时间，ISO-8601 格式（如 `2024-01-15T10:30:00+08:00`） |
| `ownerName` | String | 所有者姓名 |
| `viewCount` | Integer | 总浏览次,限 popo 文档，多维表，在线 excel |
| `userViewCount` | Integer | 用户浏览次数 |
| `fileSize` | Long | 文件大小(字节) |
| `content` | String | 文档内容。限 popo 文档和 Markdown；docType=1 内容为自定义 HTML（格式见 [popo-doc-content-format.md](./popo-doc-content-format.md)），docType=4 内容为标准 Markdown |
| `type` | Integer | 文档类型: 0-文件夹, 1-POPO文档, 2-在线excel, 3-文件, 4-在线Markdown, 9-多维表 |
| `fileType` | String | 文件类型，限文件 |

### 示例

```
popo-cli popo doc_get_doc_detail docIdOrUrl=abc123

popo-cli popo doc_get_doc_detail docIdOrUrl=https://docs.popo.netease.com/doc/xxx

# 团队空间：先解析 teamSpaceId，再调详情
popo-cli popo doc_get_folder_path url=https://docs.popo.netease.com/team/pc/technology_center/pageDetail/7a37bf7f39494258884cefb164e49cef
popo-cli popo doc_get_doc_detail docId=7a37bf7f39494258884cefb164e49cef teamSpaceId=<TEAM_SPACE_ID>
```

---

## popo_doc_get_comments

获取文档或表格的评论列表(分页)。

### 参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `docId` | String | 是 | 文档ID(云空间为 docId，团队空间为 pageId) |
| `teamSpaceId` | String | 否 | 团队空间ID，传递则查询团队空间文档评论 |
| `pageNum` | Integer | 否 | 页码，默认1 |
| `pageSize` | Integer | 否 | 每页条数，默认20，最大50 |

### 返回值 (分页)

```json
{
  "total": 100,
  "pageNum": 1,
  "pageSize": 20,
  "list": [
    {
      "commentId": "...",
      "content": "评论内容",
      "author": "作者",
      "createTime": "2024-01-15T10:30:00+08:00",
      "updateTime": "2024-01-15T10:30:00+08:00",
      "replies": []
    }
  ]
}
```

### 示例

```
popo-cli popo doc_get_comments docId=abc123 pageNum=1 pageSize=20

popo-cli popo doc_get_comments docId=page_xxx teamSpaceId=ts_xxx
```

---

## popo_doc_get_folder_path

通过团队空间文档 URL 解析文件夹 ID / teamSpaceId，或在用户明确询问文件夹 ID 时使用。不要用于 `https://docs.popo.netease.com/pages/{documentId}?nodeId=...` 云空间多维表链接；这种链接直接从 URL 提取 documentId 和 datasheetId，不需要 teamSpaceId。

### 参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `url` | String | 是 | 文档URL |

### 返回值

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `folderId` | String | 文件夹ID |
| `teamSpaceId` | String | 团队空间ID(仅团队空间文档返回) |

### 示例

```
popo-cli popo doc_get_folder_path url=https://docs.popo.netease.com/team/xxx/folder/yyy
```

---

## popo_doc_search_folder_path

通过关键词搜索文件夹(包含云空间和团队空间)。

### 参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `keyword` | String | 是 | 搜索关键词 |

### 返回值 (数组)

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `name` | String | 文件夹名称 |
| `url` | String | 访问地址 |
| `folderId` | String | 文件夹ID |
| `teamSpaceId` | String | 团队空间ID(仅团队空间文件夹有值) |

### 示例

```
popo-cli popo doc_search_folder_path keyword=项目资料
```

---

## popo_doc_search_teamspace

通过空间名字搜索团队空间。列表数量上限 1000，超过截断。

### 参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `keyword` | String | 是 | 团队空间名称关键词,为空则返回所有有权限列表 |

### 返回值 (数组)

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `teamSpaceId` | String | 团队空间ID |
| `name` | String | 团队空间名称 |
| `createdAt` | String | 创建时间 |
| `updatedAt` | String | 更新时间 |
| `teamSpaceKey` | String | 团队空间 Key |

### 示例

```
popo-cli popo doc_search_teamspace keyword=个人空间
```

---

## popo_doc_get_folder_children

获取目录子节点列表，按创建时间倒排。团队空间里任何类型节点都可以像文件夹一样放置子节点，因此 `folderId` 可以是文件夹 ID，也可以是团队空间中的文档/page ID。

### 参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `folderId` | String | 是 | 文件夹ID或团队空间的 pageId。传 "0" 表示我的空间或团队空间根目录 |
| `teamSpaceId` | String | 是 | 团队空间ID |
| `cursor` | String | 否 | 游标，用于获取下一页数据 |

### 返回值

```json
{
  "list": [
    {
      "name": "2026技术规划--1111",
      "docId": "6622f51e6cc24f49b8ea71db2ea616f1",
      "teamSpaceId": "649a481ed75d458d9f39cd6b05f7a0be",
      "creator": "liuwei13@corp.netease.com",
      "createdAt": 1775715131907,
      "hasChildren": false,
      "type": 1,
      "url": "https://docs.popo.netease.com/team/pc/vjaodqtm/pageDetail/6622f51e6cc24f49b8ea71db2ea616f1"
    }
  ],
  "more": false,
  "nextCursor": "eyJsYX..."
}
```

### 示例

```
popo-cli popo doc_get_folder_children folderId=page_xxx teamSpaceId=ts_xxx
```
