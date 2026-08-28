# POPO 文档工具参考索引

所有操作通过 Bash 执行 `popo-cli popo <工具名> key=value` 命令完成。本文件只做路由索引；执行前按任务类型读取对应参考文件。

## 文档管理

读取 [doc-management-reference.md](./doc-management-reference.md)：

- `popo_doc_create_doc`：创建文档、文件夹、Markdown、表格、多维表
- `popo_doc_delete_doc`：删除文档、文件夹、表格、多维表
- `popo_doc_search_doc`：语义搜索文档
- `popo_doc_get_doc_detail`：查看详情和内容
- `popo_doc_get_comments`：获取评论
- `popo_doc_get_folder_path`：从 URL 解析 folderId / teamSpaceId
- `popo_doc_search_teamspace`：按空间名搜索团队空间
- `popo_doc_search_folder_path`：按关键词搜索文件夹
- `popo_doc_get_folder_children`：获取目录子节点

## 内容更新

读取 [doc-update-reference.md](./doc-update-reference.md)：

- `popo_doc_update_doc`：修改标题、更新 POPO 文档内容、更新 Markdown 文档内容

写入 docType=1 的 POPO 文档内容前，还必须读取 [popo-doc-content-format.md](./popo-doc-content-format.md)。

## 文档内资源

读取 [doc-resource-reference.md](./doc-resource-reference.md)：

- `popo_doc_upload_local_file`：上传本地文件，获取可插入文档内容的资源 URL
- `popo_doc_upload_file_from_url`：上传远程 URL 文件，获取可插入文档内容的资源 URL
- `popo_doc_get_file_download_url(type=docResource)`：获取文档内图片、附件等资源的临时下载地址

## 文件类节点

读取 [file-node-reference.md](./file-node-reference.md)：

- `popo_doc_get_s3_upload_url`：获取文件类节点上传地址
- `popo_doc_create_file_node`：PUT 上传完成后创建 docType=3 文件类节点
- `popo_doc_get_file_download_url(type=fileNode)`：获取文件类节点临时下载地址
