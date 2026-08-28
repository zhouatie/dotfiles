# 文档内容更新工具参考

所有操作通过 Bash 执行 `popo-cli popo <工具名> key=value` 命令完成。

## 调用前检查

- docType=1 的 POPO 文档内容只能使用自定义 HTML，写入前必须读 [popo-doc-content-format.md](./popo-doc-content-format.md)。
- docType=4 的 Markdown 文档使用标准 Markdown。
- URL 属性值中的 `&` 严禁转义为 `&amp;`；文本节点里的 `<`、`>`、`&` 仍按 HTML 规范转义。
- 插入图片、附件、视频、音频前，先按 [doc-resource-reference.md](./doc-resource-reference.md) 上传资源并取得可写入文档的 URL。

---

## popo_doc_update_doc

修改文档标题（全部类型）或内容（POPO 文档、Markdown 文档）。

### 参数

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `docId` | String | 是 | 文档ID或 pageId |
| `title` | String | 否 | 新标题 |
| `command` | Object | 否 | 编辑命令。详见 `command 格式` 章节 |
| `teamSpaceId` | String | 否 | 团队空间ID，传递则修改团队空间文档 |

> `title` 和 `command` 至少传一个。

### 返回值

无返回体 (成功返回 status=1)。

### 示例

```
popo-cli popo doc_update_doc docId=abc123 title=新标题

popo-cli popo doc_update_doc docId=abc123 command="{\"type\": \"doc.replace_node\", \"nodeId\": \"node_1\", \"content\": \"<p>新内容</p>\"}"

popo-cli popo doc_update_doc docId=md_xxx command="{\"type\": \"md.replace_content\", \"contentUpdates\": [{\"oldStr\": \"旧文本\", \"newStr\": \"新文本\"}]}"
```

> ⚠️ **`=@file:` 仅对 `command` 参数有效**。`popo_doc_create_doc` 的 `content` 参数是普通字符串，**不支持 `=@file:`**（误用会把文件路径当字面内容写入文档）。创建带多行内容的文档时改用两步法：先 `doc_create_doc` 建空文档，再用本工具的 `doc.replace_page`（docType=1）/ `md.replace_page`（docType=4）+ `=@file:` 写入。详见 [workflows.md 工作流 1 / 1b](./workflows.md)。

### command 格式

POPO 文档（docType=1）：

| type | 参数 | 说明 |
| --- | --- | --- |
| `doc.replace_node` | `nodeId`, `content` | 替换指定节点，`content` 为自定义 HTML |
| `doc.insert_before` | `nodeId?`, `content` | 在指定节点前插入；不传 `nodeId` 时追加到文档末尾 |
| `doc.insert_after` | `nodeId?`, `content` | 在指定节点后插入；不传 `nodeId` 时追加到文档末尾 |
| `doc.replace_page` | `content` | 全量覆盖 POPO 文档，`content` 为自定义 HTML |

Markdown 文档（docType=4）：

| type | 参数 | 说明 |
| --- | --- | --- |
| `md.replace_page` | `content` | 全量覆盖 Markdown 文档，`content` 为标准 Markdown |
| `md.insert_content` | `content`, `position?` | 插入 Markdown 内容，`position` 可为 `start` 或 `end`，默认 `end` |
| `md.replace_content` | `contentUpdates` | 按文本替换，数组项格式为 `{oldStr, newStr}`；`oldStr` 应能唯一定位待替换文本 |

### 行内样式叠加语法（docType=4）

给 Markdown 文档中**同一段文本**叠加多种行内样式（粗体、斜体、删除线、下划线、高亮）时，必须按**从外到内固定顺序**嵌套，禁止拆开单独写或颠倒顺序。

**样式符对照表：**

| 样式 | 语法 | 说明 |
| --- | --- | --- |
| 粗体 | `**文本**` | 标准 Markdown |
| 斜体 | `*文本*` | 标准 Markdown |
| 粗体+斜体 | `***文本***` | 三星合写 |
| 删除线 | `~~文本~~` | 标准扩展 |
| 下划线 | `++文本++` | POPO 扩展 |
| 高亮 | `==文本==` | POPO 扩展 |

**五种样式叠加（固定顺序，外→内）：**

```
***~~++==文本==++~~***
```

拆解：`***`（粗体+斜体）→ `~~`（删除线）→ `++`（下划线）→ `==`（高亮）→ 文本 → `==`→ `++`→ `~~`→ `***` 闭合。

**错误写法（禁止）：**

- ❌ 拆开单独写：`***文本***~~文本~~++文本++==文本==`（五种样式各自作用于不同文本）
- ❌ 颠倒嵌套：`++==***~~文本~~***==++`（下划线/高亮包在外层，渲染器可能不识别）
- ❌ 仅 `***文本***` 当作五种叠加（只含粗体+斜体）
- ❌ `++==***~~文本~~***==++` 等任意非 `***~~++==...==++~~***` 顺序

**正确写法（唯一推荐）：**

```
***~~++==这是同时具有五种样式的文本==++~~***
```

**部分样式叠加：** 按相同从外到内顺序取所需子集，例如：

- 粗体+删除线：`**~~文本~~**`
- 斜体+高亮：`*==文本==*`
- 删除线+下划线+高亮：`~~++==文本==++~~`

**设置样式用 `md.replace_content`：**

`oldStr` 必须能在文档中**唯一匹配一次**。若目标文本在文档中出现多次（如标题、引用块、正文重复），需扩大 `oldStr` 上下文（带上前一行或多行）使其唯一，否则服务端返回 `oldStr must match exactly once, actual count: N`。

示例（给最后一行叠加五种样式）type": "md.replace_content",
  "contentUpdates": [
    {
      "oldStr": "> 结语：AI 不是替代工程师...\n\n结语：AI 不是替代工程师...",
      "newStr": "> 结语：AI 不是替代工程师...\n\n***~~++==结语：AI 不是替代工程师...==++~~***"
    }
  ]
}
```

> 💡 **oldStr 唯一定位技巧**：当目标行重复出现时，把该行**前面紧邻的非目标行**（如上一段、引用块）一起包进 `oldStr`，再用同样内容在 `newStr` 中保持前段不变、仅改目标行，即可保证只匹配一次。

> 🖥️ **Windows 传参**：`command` 含样式符 `***~~++==` 及中文，必须用 `=@file:` 临时文件方式（node `JSON.stringify` 生成），禁止直接内联。

> ⚠️ **渲染说明**：`++` 下划线、`==` 高亮依赖 POPO 在线 Markdown 渲染器开启对应扩展语法。若浏览器未渲染下划线/高亮，属渲染器扩展未启用，**非语法错误**；`**`、`*`、`~~` 为标准/常见扩展，通常正常渲染。

### ⚠️ command 传参方式（必读 — 不遵守会导致调用失败）

`command` 参数包含 JSON + HTML/Markdown 内容时，shell 转义极易失败；请按平台选择正确方式。更多细节见 [popo-doc-content-format.md](./popo-doc-content-format.md)。

#### Windows (PowerShell)

> 🖥️ **Windows 平台必读（不可跳过）**：
> `command` 参数包含 JSON + HTML 内容，含有大量双引号、尖括号、反斜杠等特殊字符。PowerShell 对这些字符的转义规则与 bash 完全不同，直接在命令行中传递**必然失败**。
>
> **解决方案**：将 `command` 的 JSON 值写入 UTF-8 无 BOM 临时文件，使用 `=@file:` 传参。popo-cli 会读取文件内容并解析为 JSON 对象发送，彻底绕过 shell 转义问题。

```powershell
# 仅修改标题（无特殊字符，可直接传参）
popo-cli popo doc_update_doc docId=abc123 title=新标题

# 修改内容（使用 =@file: 临时文件方式，避免特殊字符转义问题）
# Step 1: 用 node 生成 command JSON 临时文件（JSON.stringify 正确转义所有 Unicode 字符）
# ⚠️ 禁止用 PowerShell ConvertTo-Json：中文弯引号 "" 会被规范化成普通双引号导致坏 JSON
$genScript = @'
const fs = require("fs"); const path = require("path");
const cmd = { type: "doc.replace_node", nodeId: "node_1", content: "<p>新内容</p>" };
const tmp = path.join(require("os").tmpdir(), "popo_doc_command.json");
fs.writeFileSync(tmp, JSON.stringify(cmd), { encoding: "utf8" });
console.log(tmp);
'@
$cmdTmpFile = node -e $genScript

# Step 2: 使用 =@file: 传参（路径必须用双引号包裹）
popo-cli popo doc_update_doc docId=abc123 command="@file:$cmdTmpFile"

# Step 3: 清理临时文件
Remove-Item -Path $cmdTmpFile -ErrorAction SilentlyContinue
```

> ⚠️ **禁止在 Windows 上使用以下方式传递 command 参数**：
> - 直接内联 JSON（引号/尖括号被 PowerShell 截断或转义）
> - `popo-cli call POST ... --body "{...}"` HTTP 直传（`--body` 同样有转义问题）
> - 使用单引号包裹整个 command 值（PowerShell 单引号内仍有嵌套问题）
>
> **唯一可靠方式**：`=@file:` 临时文件。

#### macOS / Linux

```bash
popo-cli popo doc_update_doc docId=abc123 command='{"type": "doc.replace_node", "nodeId": "node_1", "content": "<p>新内容</p>"}'
```
