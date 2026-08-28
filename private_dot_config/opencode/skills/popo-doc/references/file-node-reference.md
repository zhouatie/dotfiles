# 文件类节点工具参考

用于把本地 Word、PPT、Excel、PDF、图片、压缩包等文件上传为独立文件类文档节点（docType=3），或获取文件类节点临时下载地址。

## 调用前检查（违反将导致严重错误）

- 上传独立文件节点必须走 `popo_doc_get_s3_upload_url` → PUT 上传 → `popo_doc_create_file_node`，不要用 `popo_doc_upload_local_file`。
- PUT 上传时不要修改 `content-type: binary/octet-stream` 和 `x-amz-acl: private`。禁止把 `content-type` 改成文件 MIME 类型，例如 `application/pdf`、`image/png`、`application/octet-stream`。
- 下载 docType=3 文件类节点时，必须通过 `popo_doc_get_file_download_url(type=fileNode)` 获取临时下载链接，不要直接使用原始地址。
- 团队空间文件节点创建必须传递接口返回的 `teamSpaceId`；下载时 `docIds` 使用团队空间 pageId，禁止手动构造。
- `popo_doc_get_file_download_url` 与 [doc-resource-reference.md](./doc-resource-reference.md) 中的工具相同，仅 `type` 参数不同。

---

## popo_doc_get_s3_upload_url

创建文件类节点前获取 S3 预签名上传 URL。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `fileName` | String | 是 | 文件名称，包含后缀；后续创建节点时必须传同一个文件名 |
| `fileSize` | Long | 是 | 文件大小，单位字节；从本地文件 stat/os.path.getsize 获取 |

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `bucketName` | String | 文件存储位置 |
| `objectKey` | String | 文件存储唯一 ID |
| `uploadId` | String | 上传 ID；创建节点时原样回传 |
| `uploadUrl` | String | S3 预签名上传 URL |

### 示例

```
popo-cli popo doc_get_s3_upload_url fileName="方案.pdf" fileSize=2389012
```

拿到 `uploadUrl` 后，直接把本地文件字节 PUT 到该 URL。

```bash
curl -X PUT -H "content-type: binary/octet-stream" -H "x-amz-acl: private" --upload-file <FILE_PATH> '<UPLOAD_URL>'
```

> `uploadUrl` 作为 shell 参数时必须整体加引号。

> ⚠️ 不要修改 `content-type: binary/octet-stream` 与 `x-amz-acl: private`。

---

## popo_doc_create_file_node

S3 上传成功后创建文件类文档节点（docType=3）。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `bucketName` | String | 是 | `popo_doc_get_s3_upload_url` 返回的文件存储位置 |
| `objectKey` | String | 是 | `popo_doc_get_s3_upload_url` 返回的文件存储唯一 ID |
| `uploadId` | String | 否 | `popo_doc_get_s3_upload_url` 返回的上传 ID；应与获取上传 URL 时一致 |
| `fileName` | String | 是 | 文件名称，包含后缀；应与获取上传 URL 时一致 |
| `folderId` | String | 否 | 所属文件夹。云空间文件夹 `folderId`，团队空间的 `docId`；为空则创建到默认位置 |
| `teamSpaceId` | String | 否 | 团队空间 ID；创建团队空间文件节点时必填 |

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `docId` | String | 文档 ID |
| `teamSpaceId` | String | 团队空间 ID，仅团队空间文件节点返回 |
| `docUrl` | String | 文档 URL 地址 |

### 示例

```
popo-cli popo doc_create_file_node bucketName=<BUCKET_NAME> objectKey=<OBJECT_KEY> uploadId=<UPLOAD_ID> fileName="方案.pdf" folderId=<FOLDER_ID>

popo-cli popo doc_create_file_node bucketName=<BUCKET_NAME> objectKey=<OBJECT_KEY> uploadId=<UPLOAD_ID> fileName="方案.pdf" folderId=<PARENT_PAGE_ID> teamSpaceId=<TEAM_SPACE_ID>
```

---

## popo_doc_get_file_download_url(type=fileNode)

获取文件类文档节点的临时下载地址（预签名 URL）。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `type` | String | 是 | 固定传 `fileNode` |
| `docIds` | List<String> | 是 | 文件类文档节点 ID 列表；云空间为 docId，团队空间为 pageId |

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `downloadUrls` | Map<String, String> | value 为预签名下载地址；key 为对应 `docId/pageId` |

### 示例

```
popo-cli popo doc_get_file_download_url type=fileNode docIds='["abc123","def456"]'
```
