# 文件版本工具参考

用于给**已存在的文件类文档（docType=3）上传新版本**，形成一个可回溯的历史版本。

流程为**三步式**，与「创建文件节点」严格区分：

```
popo_doc_get_version_upload_url（取版本上传地址）
  → PUT 上传文件字节到 uploadUrl
  → popo_doc_update_file_version（确认提交，落库新版本并切换为当前版本）
```

所有操作通过 Bash 执行 `popo-cli popo <工具名> key=value` 命令完成。

> 调用一律走 `popo-cli popo <工具名>`：CLI 授权链路挂在 `popo` 通道上，不要用 `popo-cli doc ...` / `fabric doc ...`。

## 调用前检查（违反将导致严重错误）

- **上传新版本的唯一路径** = `popo_doc_get_version_upload_url` → PUT → `popo_doc_update_file_version`。以下两个工具**都不可用于本场景**：
  - `popo_doc_upload_local_file`：用于取得「可插入文档内容的资源 URL」，**不产生版本**
  - `popo_doc_create_file_node`：用于**创建新的**文件类节点，**不是**给已有文件加版本
- 目标是**团队空间**文件时，**必须同时传 `teamSpaceId`**，且 `docId` 传 pageId；不传 `teamSpaceId` 会被当作**云空间**文件处理。
- **`fileHash` 必填**：用于**同内容阻断**与重复确认幂等。上传与当前版本**内容相同**的文件会被阻断（MCP 码 `6045`），不要把它当成工具报错反复重试。
- **两个 MD5 字段的编码不同，必须先算对**：
  - 第一步 `fileMD5` = **base64**；传了就必须让 PUT 的 `content-md5` 用**同一个 base64 值**
  - 第三步 `fileHash` **按目标空间**：云空间 = **base64**，团队空间 = **hex**
  - 判别：base64 恒 24 字符且以 `==` 结尾；hex 恒 32 字符且全为 `[0-9a-fA-F]`
- **同格式校验**：新版本文件的**扩展名必须与原文件一致**（大小写不敏感），不一致会被拒（MCP 码 `6044`）。给 `.pdf` 传 `.docx` 会被拒。
- **硬约束不变量（上传新版本前必须成立）**：`fileName` 的扩展名 == 本地源文件的**真实**扩展名 == 目标文档**当前**扩展名（大小写不敏感）。三者任一不一致 → **立即终止，禁止执行上传**，按"强制前置自检门"上报用户。
- **禁止绕过同格式校验（`6044`）—— 这是违规行为，不是技巧**：
  - ❌ 把新版本 `fileName` 改成与原文件一致的扩展名，实际上传其他格式的内容（实测：只改 `fileName` 即可让 `6044` 通过，导致 `.md` 内容覆盖 `.html` 文件节点）
  - ❌ 对源文件做 `copy` / `Copy-Item` / `cp` / `ren` / `Rename-Item` / `mv` 等改名、换后缀、或生成"后缀与实际内容不符"的临时副本后再 PUT
  - ❌ 把其他格式的内容写进以原扩展名命名的临时文件，用来掩盖真实格式
  - ❌ 改 `mimeType`、改 PUT 的 `content-type`，或改用 `popo_doc_create_file_node` 等旁路方式绕开同一条校验
  - ❌ 用"用户已同意覆盖更新"作为降低约束的理由；**用户意图不能覆盖平台校验**
  - ✅ 合规选项只有三个：换同扩展名文件重传、另建独立文件节点（`popo_doc_create_file_node`，需用户确认）、放弃更新
- **单文件上限 5GB**：`fileSize` 超过 `5 * 1024 * 1024 * 1024` 字节会被拒。
- PUT 上传时不要修改 `content-type: binary/octet-stream` 和 `x-amz-acl: private`；禁止改成文件 MIME 类型。
- `fileName` 应为**含扩展名的完整展示名**：它是**新版本的文件名**，会替换原文档名。
- `fileName` 含中文/空格时命令行必须用**双引号**包裹（Windows 禁止单引号），如 `fileName="方案-V2.pdf"`。

---

## 强制前置自检门（执行前必做，不得跳过）

上传新版本前，**必须先在回复中输出下面这张三元组自检表**（扩展名以实际取值为准，不得凭记忆或猜测），并给出比对结论；比对不通过就停止，不得进入第一步。

| 项 | 取值来源 | 扩展名 |
|---|---|---|
| 本地源文件 | 用户给出的路径，如 `会话导出_2026-09-01.md` | `.md` |
| `fileName`（第一步 / 第三步都要传） | 即将传参的值 | `.html` |
| 目标文档当前名 | 目标 `docId` 对应的文件名，如 `ai_dev_practice.html` | `.html` |

- 只有三者扩展名完全一致，才允许继续执行三步式流程。
- `本地源文件` 与 `目标文档当前名` 不一致时**直接终止**，不做任何"兼容处理"：不改 `fileName`、不改本地文件名、不复制成原后缀、不改 `mimeType`。
- 禁止"先上传、失败再说"，也禁止"失败后改个名字重试"。自检门的要求是**先证明一致，再动手**。
- 若历史上已产生违规版本（例如 `.md` 内容覆盖了 `.html` 节点），只能**如实上报**，由用户决定是否用原内容重传为新版本回滚；不得悄悄处理或隐瞒。
- 校验被拦截时的标准回话模板：`按规则，<源扩展名> 无法更新 <目标扩展名> 文件节点（6044），已停止操作。可选：① 换同扩展名文件 ② 另建独立文件节点 ③ 放弃更新`

---

## popo_doc_get_version_upload_url

上传新版本第一步：按文件信息获取版本上传地址。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `fileName` | String | 是 | 文件名称，包含扩展名 |
| `fileSize` | Long | **是** | 文件大小，单位字节；从本地文件 stat/os.path.getsize 获取 |
| `fileMD5` | String | 否 | 文件 md5（**base64**）；**传了就必须在后续 PUT 带上同值的 `content-md5` 头**，见下方示例注记 |

> 本步**不需要 docId**：只按文件信息取上传地址。

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `endpoint` | String | S3 endpoint；确认提交时**建议回传**（省略则用服务端默认） |
| `bucketName` | String | 文件存储位置；确认提交时原样回传 |
| `objectKey` | String | 文件存储唯一 ID；确认提交时原样回传 |
| `uploadId` | String | 上传 ID |
| `uploadUrl` | String | S3 预签名上传 URL |

### 示例

```
popo-cli popo doc_get_version_upload_url fileName="方案-V2.pdf" fileSize=2389012
```

拿到 `uploadUrl` 后，把本地文件字节 PUT 到该 URL：

```bash
curl -X PUT -H "content-type: binary/octet-stream" -H "x-amz-acl: private" --upload-file <FILE_PATH> '<UPLOAD_URL>'
```

> `uploadUrl` 作为 shell 参数时必须整体加引号。

> **第一步传了 `fileMD5` 时**，PUT **必须**同时带上 `content-md5: <MD5_BASE64>` 头，且用**与第一步完全相同的 base64 值**（该值会进签名），否则签名不匹配：
>
> ```bash
> curl -X PUT -H "content-type: binary/octet-stream" -H "x-amz-acl: private" -H "content-md5: <MD5_BASE64>" --upload-file <FILE_PATH> '<UPLOAD_URL>'
> ```
>
> 中途改了 `fileMD5` 的编码或取值后，必须**重新调用第一步**取新的 `uploadUrl` —— 旧地址仍按旧值签名，直接复用会签名失败。

---

## popo_doc_update_file_version

上传新版本第二步：确认提交并切换为当前版本。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `docId` | String | 是 | 文件 ID；云空间为 docId，团队空间为 pageId |
| `teamSpaceId` | String | 否 | 团队空间 ID；**传值表示团队空间文件，不传表示云空间文件** |
| `fileName` | String | 是 | 文件名称，包含扩展名；即新版本的展示名 |
| `fileSize` | Long | 是 | 文件大小，单位字节 |
| `fileHash` | String | 是 | 文件 md5；**云空间传 base64、团队空间传 hex**；用于同内容阻断与重复确认幂等 |
| `bucketName` | String | 是 | 取 `popo_doc_get_version_upload_url` 返回值 |
| `objectKey` | String | 是 | 取 `popo_doc_get_version_upload_url` 返回值 |
| `endpoint` | String | 否 | 建议回传，取 `popo_doc_get_version_upload_url` 返回值；省略则用服务端默认 endpoint |
| `mimeType` | String | 否 | 媒体类型 |

### 返回值

| 字段 | 类型 | 说明 |
|------|------|------|
| `docId` | String | 文件 ID；云空间为 docId，团队空间为 pageId |
| `versionNo` | Integer | 新版本号 |
| `status` | String | 版本状态；`SUCCESS` = 已生效 |

### 示例

云空间文件：

```
popo-cli popo doc_update_file_version docId=<DOC_ID> fileName="方案-V2.pdf" fileSize=2389012 fileHash=<MD5_BASE64> bucketName=<BUCKET_NAME> objectKey=<OBJECT_KEY>
```

团队空间文件（**多传 `teamSpaceId`**，`docId` 用 pageId）：

```
popo-cli popo doc_update_file_version docId=<PAGE_ID> teamSpaceId=<TEAM_SPACE_ID> fileName="方案-V2.pdf" fileSize=2389012 fileHash=<MD5_HEX> bucketName=<BUCKET_NAME> objectKey=<OBJECT_KEY>
```

`status=SUCCESS` 即新版本已生效。历史版本与回滚由文档界面/服务端管理，本工具只负责**上传并切换当前版本**。

> 与「创建文件类节点」的区别见 [file-node-reference.md](./file-node-reference.md)：新节点走 `popo_doc_get_s3_upload_url` → PUT → `popo_doc_create_file_node`；给已有文件加版本走本文档的三步式。

---

## 报错排查

| 返回 | 含义与处理 |
|------|-----------|
| `FABRIC_TOOL_NOT_FOUND` | 工具路由未命中，核对工具名是否为 `popo-cli popo doc_get_version_upload_url` / `popo-cli popo doc_update_file_version` |
| `FABRIC_EXPIRED`（授权已过期） | 先执行 `fabric auth refresh`，再重试；仍失败则看下一条 |
| `FABRIC_PENDING`（授权卡片已发送） | 授权卡片已下发到 POPO，需**用户本人确认**后才能继续；**禁止自动反复重试**，先通知用户 |
| `FABRIC_DOWNSTREAM_ERROR` / `FABRIC_DOWNSTREAM_UNAVAILABLE` | 路由存在但下游 500/503，属服务端不可用，稍后重试即可，不要改参数硬试 |
| `status:414`（如 `fileHash fileHash不能为空`） | 业务层参数校验失败，HTTP 仍为 200；`fileHash` 必填，云空间传 base64、团队空间传 hex |
| MCP 码 `6045` | 新版本与当前版本内容相同，属**正常同内容阻断**，不要反复重试 |
| MCP 码 `6044` | 新版本扩展名与原文件不一致，改用同格式文件。**禁止绕过**：不得只改 `fileName`、不得把本地文件改名/复制成原扩展名后上传、不得改 `mimeType`；必须停止并告知用户，由用户选择换同格式文件 / 另建节点 / 放弃 |
