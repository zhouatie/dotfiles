# 文档内容格式说明

本文件描述POPO文档 (docType=1) 的 HTML 内容格式，适用于以下场景：

- `getDocDetail` 返回的 `content` 字段 -- 读取文档内容（标签带 `id` 属性）
- `updateDoc` 的 `command` 参数 -- 按块更新文档内容

---

## ❌ 常见错误（Agent 高频犯错，必须避免）

**content 字段只接受自定义 HTML 标签，以下写法全部会导致格式错误：**

| ❌ 错误写法 | ✅ 正确写法 | 说明 |
|---|---|---|
| `## 标题` | `<h2>标题</h2>` | 禁止 Markdown 标题 |
| `- 列表项` / `* 列表项` | `<doc-li list-id="l1" list-type="unordered">列表项</doc-li>` | 禁止 Markdown 无序列表 |
| `1. 有序项` | `<doc-li list-id="l1" list-type="ordered">有序项</doc-li>` | 禁止 Markdown 有序列表 |
| `**粗体**` | `<b>粗体</b>` | 禁止 Markdown 粗体 |
| `*斜体*` | `<i>斜体</i>` | 禁止 Markdown 斜体 |
| `` `行内代码` `` | `<code>行内代码</code>` | 禁止 Markdown 行内代码 |
| ` ```python\ncode\n``` ` | `<code-block language="python">code</code-block>` | 禁止 Markdown 代码块 |
| `<ul><li>项目</li></ul>` | `<doc-li list-id="l1" list-type="unordered">项目</doc-li>` | 禁止标准 HTML 列表 |
| `<ol><li>项目</li></ol>` | `<doc-li list-id="l1" list-type="ordered">项目</doc-li>` | 禁止标准 HTML 有序列表 |
| `<pre><code>code</code></pre>` | `<code-block language="python">code</code-block>` | 禁止标准 HTML 代码块 |
| `- [ ] 待办` | `<todo-item checked="">待办</todo-item>` | 禁止 Markdown 待办 |
| `> 引用` | `<blockquote><p>引用</p></blockquote>` | 禁止 Markdown 引用 |
| `---` | `<hr />` | 禁止 Markdown 分割线 |

---

## getDocDetail 返回内容格式

返回的 `content` 字段也是 HTML 片段，但每个块级标签会带有系统生成的 `id` 属性，用于后续按块更新：

```html
<p id='uyPT-1773837004807'>我是内容</p>
<img id='x3Dw-1773838123104' src='https://xxxx.xxxxcowork.www.com/api/admin/file/download?path=popo/2026/03/18/97e9b153800745e89a88bdfffa9cc023.png' />
```

> 如果 POPO文档(docType=1) 的 content 中包含图片或其他资源，需要提取 `src` 中的链接，通过 `popo_doc_get_file_download_url` 获取临时下载地址后才能下载；团队空间文档必须同时传 `teamSpaceId`。多维表(docType=9)附件字段不适用本规则，必须走 `popo_doc_file_batch_get`。

## updateDoc command 格式

`command` 包含三个参数：

| 参数 | 说明 |
|------|------|
| `type` | 操作类型：`doc.replace_node`、`doc.insert_before`、`doc.insert_after` |
| `nodeId` | 从 `getDocDetail` 返回内容中的 `id` 属性获取。`doc.insert_after` 可省略，省略时内容追加到文档末尾 |
| `content` | HTML 内容（遵循下方格式规则） |

```json
{"type": "doc.replace_node", "nodeId": "uyPT-1773837004807", "content": "<p>新内容</p>"}
{"type": "doc.insert_after", "nodeId": "uyPT-1773837004807", "content": "<p>在指定节点后插入</p>"}
{"type": "doc.insert_after", "content": "<p>追加到文档末尾</p>"}
{"type": "doc.replace_node", "nodeId": "uyPT-1773837004807", "content": ""}
```

### ⚠️ command 传参方式（必读 — 不遵守会导致调用失败）

`command` 参数的 JSON 值包含 HTML 标签（`<>`、`"` 等特殊字符），不同平台传参方式不同：

**Windows (PowerShell) — 必须使用 `@file:` 临时文件，禁止直接内联：**

```powershell
# 1. JSON 写入临时文件（UTF-8 无 BOM）
$cmdJson = '{"type": "doc.insert_after", "content": "<h1>标题</h1><p>内容</p>"}'
$cmdTmpFile = Join-Path $env:TEMP "popo_doc_command.json"
[System.IO.File]::WriteAllText($cmdTmpFile, $cmdJson, [System.Text.UTF8Encoding]::new($false))
# 2. "@file:" 传参（路径必须用双引号包裹）
popo-cli popo doc_update_doc docId=<DOC_ID> command="@file:$cmdTmpFile"
# 3. 清理临时文件
Remove-Item -Path $cmdTmpFile -ErrorAction SilentlyContinue
```

**macOS / Linux (bash/zsh) — 单引号包裹即可：**

```bash
popo-cli popo doc_update_doc docId=<DOC_ID> command='{"type": "doc.insert_after", "content": "<h1>标题</h1><p>内容</p>"}'
```

> ❌ 在 Windows 上直接内联 `command="{\"type\":...\"<h1>...\"}"` **必然失败**，PowerShell 会截断尖括号和双引号。

---

## 核心规则

1. **不写 `id`** — 系统自动生成
2. **纯文本裸写** — 不加无意义的包装标签；需要颜色/下划线时用 `<span style="...">` 是合法的，见行内元素说明
3. **不写 `style`** — 除非用户明确要求对齐、缩进、背景色
4. **只用下方白名单中的标签** — 不要使用任何清单之外的 HTML 标签
5. **属性不加 `data-` 前缀** — 直接写 `fold="true"`，不写 `data-fold="true"`
6. **一级节点约束** — `table`、`callout`、`diagram`、`drawio`、`media` 不能被嵌套，只能作为文档一级节点使用

## 允许的标签白名单

### 块级标签

- `p` — 段落
- `h1`~`h6` — 标题，标签名即层级
  - `fold="true"` — 可折叠
- `blockquote` — 引用块，左侧灰色竖线+灰色文字，同 Markdown 引用风格，适合低调引用；内部放 block
- `doc-li` — 同 markdown 列表，区别是有序序号由 `list-id` 维系，中间插入其他 block 不会打断编号
  - `list-id` — 同一列表共享同一值，决定编号连续性
  - `list-type` — `ordered` / `unordered`
  - `list-level` — 层级，默认 `1`
- `doc-li-head` — 标题前面带上列表编号，根据目录结构自动生成论文风格带编号（1. / 1.1. / 1.1.1.），适合有编号章节大纲；属性同 `doc-li`，另加：
  - `heading-level` — `1`~`6`，标题级别
- `todo-item` — 待办项，样式为复选框+文本；
  - `checked=""` — 未完成
  - `checked="checked"` — 已完成
- `code-block` — 代码块，内容为纯文本，行间用 `\n`
  - `language` — 如 `javascript`、`python`
  - `wrap="true"` — 自动换行（可选）
  - `folded="true"` — 折叠（可选）
- `table` — 表格；结构`colgroup`/`tbody`/`tr`/`td`
  - `title-line-open` - 第一行为标题样式
  - `title-bar-open` - 第一列为标题样式
- `callout` — 高亮提示块，彩色背景圆角块+左侧 emoji，视觉强调度高（区别于 blockquote：有背景色和 emoji）；只能作为文档一级节点；
  - `emoji` — 任意 emoji 字符
  - `bg-color` — 任意颜色或渐变，如 `rgb(255,251,235)` / `linear-gradient(...)`
- `img` — 图片；占据整行
  - `src`
- `attachment` — 附件；渲染为文件卡片，可点击下载
  - `file-name` — 文件名（**必填**）
  - `src` — 下载链接（**必填**）；URL 查询参数（尤其是 `fileName=`）含中文/空格/`&` 等字符时必须**百分号编码**（`%XX`），否则会破坏 URL 结构。但 URL 中的 `&` **严禁转义为 `&amp;`**（见下方图片/附件说明）
  - `file-size` — 文件大小，单位 B（**必填**）；服务端校验，缺失会返回 `Attachment node requires fileSize attribute.`
- `hr` — 分割线，写 `<hr />`；视觉与 Markdown `---` 一致
- `diagram` — 图表（PlantUML 等），内容为纯文本，支持实时预览；只能作为文档一级节点；
  - `language` — `PlantUML` or `Mermaid`,必填
- `drawio` — Draw.io 画布；只能作为文档一级节点；
  - `url`, `referencekey`, `version`
- `media` — 第三方嵌入（Figma 等）；只能作为文档一级节点；
  - `href` — 嵌入地址
  - `source` — 来源类型，如 `figma`
- `video` — 视频；
  - `src`, `title`
- `audio` — 音频；
  - `src`
  - `file-name` — 文件名（别设置，自动从 src 里获取）
- `mindmap` — 思维导图/白板；
  - `type="mindmap"`
  - `snapshot` — 快照图片地址

### 行内元素

普通文本直接裸写，不加任何标签。需要语义或样式时使用以下标签：

**语义标签**（视觉与标准 HTML / Markdown 一致）：

- `b` — 粗体
- `i` — 斜体
- `del` — 删除线
- `code` — 行内代码
- `a` — 链接，`href` 指定地址
- `mention` — @提及，`email` 指定用户

**样式标签**（仅在需要颜色、高亮、下划线时使用 `<span style="...">`，不要用它包裹无样式的普通文本）：

- `color: rgb(r, g, b);` — 文字颜色
- `background-color: rgb(r, g, b);` — 文字高亮背景
- `text-decoration: underline;` — 下划线

## 高频标签速查

### 段落

```html
<p>正文内容</p>
```

### 标题

```html
<h1>一级标题</h1>
<h2>二级标题</h2>
```

### 列表

列表是扁平结构，不用 `<ul>/<ol>/<li>`。同一列表共享 `list-id`。

```html
<doc-li list-id="l1" list-type="unordered">无序项 1</doc-li>
<doc-li list-id="l1" list-type="unordered">无序项 2</doc-li>

<doc-li list-id="l2" list-type="ordered">有序项 1</doc-li>
<doc-li list-id="l2" list-type="ordered">有序项 2</doc-li>
<doc-li list-id="l2" list-type="ordered" list-level="2">子项 2.1</doc-li>
```

### 代码块

内容是纯文本，多行代码用换行符 `\n` 分隔，不要按行包标签，不要插入 `<br>`。

```html
<code-block language="python">def hello(): print("Hello, World!") hello()</code-block>
```

### 待办

```html
<todo-item checked="">未完成</todo-item> <todo-item checked="checked">已完成</todo-item>
```

### 引用

内部放 block 标签。

```html
<blockquote>
  <p>引用内容</p>
</blockquote>
```

### 分割线

```html
<hr />
```

### 简单表格

> ⚠️ 写入表格前，**必须先读取 [`tags/table.md`](./tags/table.md)** 获取完整的结构规则、属性说明和合并单元格用法。

`<td>` 内支持嵌套段落、列表、代码块等块级标签；纯文本内容会自动包成段落。

启用标题行：

```html
<table title-line-open>
  <colgroup>
    <col style="width: 180px;" />
    <col style="width: 220px;" />
  </colgroup>
  <tbody>
    <tr>
      <th>字段</th>
      <th>说明</th>
    </tr>
    <tr>
      <td>name</td>
      <td>用户名</td>
    </tr>
    <tr>
      <td>email</td>
      <td>邮箱地址</td>
    </tr>
  </tbody>
</table>
```

单元格内嵌套 block：

```html
<td>
  <p><b>功能说明</b></p>
  <doc-li list-id="l1" list-type="unordered">支持多行内容</doc-li>
  <doc-li list-id="l1" list-type="unordered">支持代码块、列表等</doc-li>
</td>
```

### 高亮块

```html
<callout emoji="💡" bg-color="rgb(255, 251, 235)">
  <p>提示内容</p>
</callout>
```

### 图片、附件
本地图片必须先调用 `popo_doc_upload_local_file` 获取 URL，再写入 `src`；远程图片/CDN 文件必须先调用 `popo_doc_upload_file_from_url` 获取 URL；不要把本地文件路径或远程直链直接写进文档内容。

> ❗ **URL 中的 `&` 严禁转义为 `&amp;`**。
>
> ✅ 正确：`src="...?path=xxx&type=attachment&identity=yyy&fileName=报告.pdf"`
> ❌ 错误：`src="...?path=xxx&amp;type=attachment&amp;identity=yyy&amp;fileName=报告.pdf"`
>
> 注意：这条规则**只针对 URL 属性值里的 `&`**。文本节点（`<p>` 内的正文）里的 `<` `>` `&` 仍需按 HTML 规范实体化为 `&lt;` `&gt;` `&amp;`。

```html
<img src="https://example.com/image.png" />

<attachment file-name="report.pdf" file-size="2048" src="https://example.com/api/admin/file/download?path=abdwqsdwq&type=attachment&identity=sdwqweqwdwqxx&fileName=report.pdf" />
<audio src="https://example.com/api/admin/file/download?path=abdwqsdwq&type=attachment&identity=sdwqweqwdwqxx" />


```

## Recipes

### 带格式的正文

```html
<h2>项目概述</h2>
<p>本项目旨在实现<b>自动化部署</b>，详见 <a href="https://example.com">文档</a>。</p>
<p>关键指标如下：</p>
<doc-li list-id="l1" list-type="unordered">部署时间 &lt; 5 分钟</doc-li>
<doc-li list-id="l1" list-type="unordered">成功率 &gt; 99.9%</doc-li>
```

### 多级有序列表

同一有序列表的 `list-id` 必须一致，层级由 `list-level` 控制。即使中间插入其他一级节点，后续序号也会连续。

```html
<doc-li list-id="l1" list-type="ordered">第一章</doc-li>
<doc-li list-id="l1" list-type="ordered" list-level="2">第一节</doc-li> 
<doc-li list-id="l1" list-type="ordered" list-level="3">第一小节</doc-li> 
<doc-li list-id="l1" list-type="ordered" list-level="2">第二节</doc-li>
<p>中途插入其他节点，不影响列表序号。</p>
<doc-li list-id="l1" list-type="ordered">第二章</doc-li> 
<doc-li list-id="l1" list-type="ordered" list-level="2">第一节</doc-li> 
```

### 引用内嵌内容

```html
<blockquote>
  <p><b>注意：</b>以下条件必须同时满足。</p>
  <doc-li list-id="l1" list-type="ordered">条件一</doc-li>
  <doc-li list-id="l1" list-type="ordered">条件二</doc-li>
</blockquote>
```

### callout 内嵌内容

```html
<callout emoji="⚠️" bg-color="rgb(255, 243, 240)">
  <p><b>风险提示</b></p>
  <p>此操作不可撤销，请确认后再执行。</p>
</callout>
```

### 行内样式

颜色和高亮用 `<span style="...">`，不要用它包裹无样式的普通文本。

```html
<p>状态：<span style="color: rgb(220, 38, 38);">失败</span></p>
<p>注意 <span style="background-color: rgb(254, 249, 195);">此处配置</span> 需要重启生效。</p>
<p><span style="text-decoration: underline;">查看详情</span></p>
```

## 标签详细说明

`tags/` 目录下为每个标签提供了完整的属性、结构规则和示例，**遇到不确定的标签用法时，必须先读取对应文件，不得凭印象写**：

| 标签 | 说明文件 | 何时必读 |
|---|---|---|
| `table` | [`tags/table.md`](./tags/table.md) | 写任何表格前 |
| `doc-li` | [`tags/doc-li.md`](./tags/doc-li.md) | 有多级列表或嵌套需求时 |
| `doc-li-head` | [`tags/doc-li-head.md`](./tags/doc-li-head.md) | 需要带编号章节标题时 |
| `callout` | [`tags/callout.md`](./tags/callout.md) | 写高亮提示块时 |
| `code-block` | [`tags/code-block.md`](./tags/code-block.md) | 写代码块时 |
| `todo-item` | [`tags/todo-item.md`](./tags/todo-item.md) | 写待办项时 |
| `img` | [`tags/img.md`](./tags/img.md) | 写图片时 |
| `diagram` | [`tags/diagram.md`](./tags/diagram.md) | 写 PlantUML/Mermaid 图时 |
| `drawio` | [`tags/drawio.md`](./tags/drawio.md) | 写 Draw.io 画布时 |
| `media` | [`tags/media.md`](./tags/media.md) | 嵌入 Figma 等第三方内容时 |
| `video` | [`tags/video.md`](./tags/video.md) | 涉及视频时 |
| `audio` | [`tags/audio.md`](./tags/audio.md) | 涉及音频时 |
| `mindmap` | [`tags/mindmap.md`](./tags/mindmap.md) | 写思维导图时 |

## 禁忌

- **代码块内按行包 `<code>` 标签** — 代码块内容是纯文本 + 换行符
- **纯文本用 `<span>` 包裹** — 直接写文本
- **给文本节点加 `id`** — 只有 block 标签才有 `id`，且你不需要写
- **使用 `<pre><code>` 写代码块** — 用 `<code-block>`
- **使用 `<ul><li>` / `<ol><li>` 写列表** — 用 `<doc-li>`
- **嵌套 `table` / `callout` / `diagram` / `drawio` / `media`** — 这些标签只能作为文档一级节点，不能放进 `blockquote`、`doc-li`、`callout`、`table cell` 等容器里
