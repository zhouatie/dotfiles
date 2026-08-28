# 在线表格工具参考

所有表格操作统一使用 `popo_doc_execute_table` 工具，通过 Bash 执行 `popo-cli` 命令调用：

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "<commandType>", "payload": {...}}' teamSpaceId=<可选>
```

## 通用说明

| 术语 | 含义 |
|------|------|
| **可见索引** | 跳过隐藏行/列后的序号（0-based） |
| **物理索引** | 包含所有行/列（含隐藏）的原始序号（0-based） |
| `version` | 操作后的版本号；幂等操作无变化时可能为 `undefined` |
| `sheetId` | 全局唯一 Sheet 标识，UUID 格式 |
| 公式格式 | 入参以 `=` 开头（如 `=SUM(A1:B2)`） |

**索引规则**：
- 插入 / 删除 / 调整大小 / 隐藏 操作使用**可见索引**
- 显示隐藏行列（sheet.showRows / sheet.showCols）使用**物理索引**

---

## workbook.getFullData — 获取表格完整数据

获取整个 Workbook 或指定 Sheet 的完整数据，包括单元格值、合并区域、Sheet 元信息等。只读操作。

### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 否 | 指定 Sheet ID；不填则返回所有 Sheet 的数据 |

### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "workbook.getFullData", "payload": {}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "workbook.getFullData", "payload": {"sheetId": "<SHEET_ID>"}}'
```

### 返回值

```json
{
  "tabs": ["sheet-id-1", "sheet-id-2"],
  "sheets": [
    {
      "sheetId": "sheet-id-1",
      "title": "Sheet1",
      "rowCount": 200,
      "colCount": 20,
      "indexBase": 0,
      "cells": [
        { "row": 0, "col": 0, "address": "A1", "value": "Hello" },
        { "row": 0, "col": 1, "address": "B1", "formula": "=SUM(A1:A5)", "value": null },
        { "row": 1, "col": 0, "address": "A2", "value": 42 }
      ],
      "spans": { "0,0": [2, 3] },
      "rowHeights": { "0": 25, "5": 50 },
      "colWidths": { "0": 80, "3": 200 },
      "hiddenRows": [3, 7],
      "hiddenCols": [2],
      "charts": [
        {
          "chartId": "123456789",
          "title": "销售趋势",
          "domain": "A1:C5",
          "type": "line",
          "location": [300, 500, 400, 500],
          "colorScheme": "s0"
        }
      ],
      "hidden": false
    }
  ]
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `tabs` | string[] | Sheet 顺序数组（sheetId 列表） |
| `sheets[].sheetId` | string | Sheet ID |
| `sheets[].title` | string | Sheet 名称 |
| `sheets[].rowCount` | number | 行总数（含隐藏行） |
| `sheets[].colCount` | number | 列总数（含隐藏列） |
| `sheets[].indexBase` | 0 | `cells` 中 `row` / `col` 的索引基准 |
| `sheets[].cells` | CellData[] | 有值单元格的稀疏数组；空单元格不出现 |
| `sheets[].spans` | Record\<"row,col", [rowCount, colCount]\> | 合并单元格区域 |
| `sheets[].rowHeights` | Record\<string, number\> | 自定义行高(px)；未设置的行使用默认值 |
| `sheets[].colWidths` | Record\<string, number\> | 自定义列宽(px)；未设置的列使用默认值 |
| `sheets[].hiddenRows` | number[] | 被隐藏的行的物理索引(0-based) |
| `sheets[].hiddenCols` | number[] | 被隐藏的列的物理索引(0-based) |
| `sheets[].charts` | ChartInfo[] | 图表列表 |
| `sheets[].hidden` | boolean | 该 Sheet 是否隐藏 |

`CellData` 每项结构：

| 字段 | 类型 | 说明 |
|------|------|------|
| `row` | number | 行索引，基于 `indexBase` |
| `col` | number | 列索引，基于 `indexBase` |
| `address` | string | Excel A1 地址，如 `B1` |
| `value` | any | 普通单元格的可读值；公式单元格为 `null` |
| `formula` | string | 公式单元格返回，带 `=` 前缀；普通值单元格不返回该字段 |

> 指定不存在的 `sheetId` 不会报错，返回空结构。

---

## sheet.setCell — 设置单元格

设置指定单元格的值、公式、富文本、样式、显示格式或交互类型，如果要清空单元格，必须使用 clearCell。

### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `row` | Integer | 是 | 行索引（可见行，0-based） |
| `col` | Integer | 是 | 列索引（可见列，0-based） |
| `value` | any | 与 formula/richText 三选一 | 单元格值（数字/字符串） |
| `formula` | String | 与 value/richText 三选一 | 公式，以 `=` 开头，如 `=SUM(A1:A3)` |
| `richText` | Object | 与 value/formula 三选一 | 富文本值，片段样式支持加粗、斜体、下划线、删除线、字体颜色 |
| `style` | Object | 内容/格式字段为空时必填，否则可选 | 单元格样式，字段见下方"style 样式对象" |
| `format` | String/Object | 内容/样式字段为空时必填，否则可选 | 单元格显示格式，支持百分比、小数位、货币、会计、日期、时间等 |
| `dropdown` | Object | 内容/样式/格式为空时必填，否则可选 | 设置为下拉选项单元格 |
| `checkbox` | true/Object | 内容/样式/格式为空时必填，否则可选 | 设置为复选框单元格 |
| `hyperlink` | String/Object | 内容/样式/格式为空时必填，否则可选 | 设置为超链接单元格 |
| `imageUrl` / `image` | String/Object | 内容/样式/格式为空时必填，否则可选 | 设置为单元格图片；图片 URL 由上游上传后提供 |

> `value`、`formula`、`richText` 互斥；`style`、`format`、`dropdown`、`checkbox`、`hyperlink`、`imageUrl` 可单独传，也可与内容一起传。

### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.setCell", "payload": {"sheetId": "<SHEET_ID>", "row": 0, "col": 0, "value": 100}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.setCell", "payload": {"sheetId": "<SHEET_ID>", "row": 0, "col": 0, "formula": "=SUM(A1:A3)"}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.setCell", "payload": {"sheetId": "<SHEET_ID>", "row": 5, "col": 0, "style": {"wrap": "wrap"}}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.setCell", "payload": {"sheetId": "<SHEET_ID>", "row": 1, "col": 0, "dropdown": {"items": ["待处理", "进行中", "已完成"]}}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.setCell", "payload": {"sheetId": "<SHEET_ID>", "row": 1, "col": 1, "checkbox": true}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.setCell", "payload": {"sheetId": "<SHEET_ID>", "row": 1, "col": 2, "hyperlink": {"url": "https://example.com", "text": "Example"}}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.setCell", "payload": {"sheetId": "<SHEET_ID>", "row": 1, "col": 3, "imageUrl": "https://example.com/image.png"}}'
```

### 返回值

```json
{ "sheetId": "string", "row": 0, "col": 0, "version": 1 }
```

### ⚠️ imageUrl 实际 URL 的 Windows 传参（必读）

`doc_upload_local_file` / `doc_upload_file_from_url` 返回的图片 URL **不是简单 URL**，而是带 query 参数和 JSON 片段的复杂字符串，例如：

```
https://cospread.cowork.netease.com/api/admin/file/download?path=popo/2026/07/02/xxx.jpg&extraParams={"teamSpaceId":"xxx","pageId":"xxx","locationType":"2"}
```

该 URL 同时包含 `&`、`"`、`{`、`}` 四类特殊字符。在 Windows CMD/PowerShell 上直接内联到 `command` 参数**必然失败**（`&` 被解释为命令分隔符，`"` 被截断，`{}` 解析异常）。

**必须使用 `=@file:` 临时文件方式**：

```powershell
# Step 1: 用 node 生成 command JSON 临时文件（node 原生 JSON.stringify，正确转义所有字符）
$genScript = @'
const fs = require("fs"); const path = require("path");
const cmd = {
  type: "sheet.setCell",
  payload: {
    sheetId: "0", row: 5, col: 4,
    imageUrl: "<UPLOADED_IMAGE_URL>"
  }
};
const tmp = path.join(require("os").tmpdir(), "popo_img_cmd.json");
fs.writeFileSync(tmp, JSON.stringify(cmd), { encoding: "utf8" });
console.log(tmp);
'@
$cmdTmpFile = node -e $genScript

# Step 2: 用 @file: 传参（路径必须用双引号包裹）
popo-cli popo doc_execute_table docId=<DOC_ID> teamSpaceId=<TEAM_SPACE_ID> command="@file:$cmdTmpFile"

# Step 3: 清理临时文件
Remove-Item -Path $cmdTmpFile -ErrorAction SilentlyContinue
```

> ⚠️ **禁止用 PowerShell `ConvertTo-Json`** 生成 command JSON：中文弯引号 `"` `"`（U+201C/U+201D）会被规范化成普通双引号 `"` 且不转义，产生坏 JSON 导致 `command.type is required`。**必须用 node 的 `JSON.stringify`**，它对所有 Unicode 字符正确转义。
> ⚠️ `imageUrl` 也支持对象形式 `{ "url": "<URL>" }`，但复杂 URL 同样需走 `=@file:` 临时文件方式。
> ⚠️ 此规则同样适用于 `hyperlink` 字段含复杂 URL 的场景。

---

## sheet.clearCell — 清空单元格

清除指定单元格的内容，幂等操作。

### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `row` | Integer | 是 | 行索引（0-based） |
| `col` | Integer | 是 | 列索引（0-based） |

### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.clearCell", "payload": {"sheetId": "<SHEET_ID>", "row": 0, "col": 0}}'
```

### 返回值

```json
{ "sheetId": "string", "row": 0, "col": 0, "version": 1 }
```

---

## sheet.batchSetCells — 批量设置单元格（每次最多 1000 个单元格）

一次性设置多个单元格的值、公式、富文本、样式、显示格式或交互类型。

### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `cells` | Array | 是 | 单元格数组，每项含 `row`、`col` 及写入内容/样式/格式 |

`cells` 每项结构:

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `row` | number >= 0 | 是 | 行索引 |
| `col` | number >= 0 | 是 | 列索引 |
| `value` | any | 与 formula/richText 三选一 | 单元格值 |
| `formula` | string | 与 value/richText 三选一 | 公式（以 `=` 开头） |
| `richText` | object | 与 value/formula 三选一 | 富文本值，同 setCell |
| `style` | object | 内容/格式字段为空时必填，否则可选 | 单元格样式，同 setCell，字段见下方"style 样式对象" |
| `format` | string/object | 内容/样式字段为空时必填，否则可选 | 单元格显示格式，同 setCell |
| `dropdown` | object | 内容/样式/格式为空时必填，否则可选 | 下拉选项，同 setCell |
| `checkbox` | true/object | 内容/样式/格式为空时必填，否则可选 | 复选框，同 setCell |
| `hyperlink` | string/object | 内容/样式/格式为空时必填，否则可选 | 超链接，同 setCell |
| `imageUrl` / `image` | string/object | 内容/样式/格式为空时必填，否则可选 | 单元格图片，同 setCell |

### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.batchSetCells", "payload": {"sheetId": "<SHEET_ID>", "cells": [{"row": 0, "col": 0, "value": "Name"}, {"row": 0, "col": 1, "formula": "=SUM(B2:B10)"}]}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.batchSetCells", "payload": {"sheetId": "<SHEET_ID>", "cells": [{"row": 5, "col": 0, "value": "长文本...", "style": {"wrap": "wrap"}}]}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.batchSetCells", "payload": {"sheetId": "<SHEET_ID>", "cells": [{"row": 1, "col": 0, "dropdown": {"items": ["待处理", "进行中", "已完成"]}}, {"row": 1, "col": 1, "checkbox": true}, {"row": 1, "col": 2, "hyperlink": {"url": "https://example.com", "text": "Example"}}, {"row": 1, "col": 3, "imageUrl": "https://example.com/image.png"}]}}'
```

### 返回值

```json
{ "sheetId": "string", "updatedCount": 3, "version": 1 }
```

---

## style 样式对象

`sheet.setCell` 和 `sheet.batchSetCells` 的每个 cell 均支持可选 `style` 字段，用于设置单元格样式属性。`style` 是一个对象，全部字段可选，可单独设置任一字段，也可组合设置多个字段。

### 字段说明

| 字段 | 类型 | 可选值 | 说明 |
|------|------|--------|------|
| `bold` | Boolean | `true` / `false` | 加粗 |
| `italic` | Boolean | `true` / `false` | 斜体 |
| `underline` | Boolean | `true` / `false` | 下划线 |
| `strikethrough` | Boolean | `true` / `false` | 删除线 |
| `fontFamily` | String | 见下方字体列表 | 字体名（不能传字体值，gateway 会把字体名转换为实际字体值写入表格） |
| `fontSize` | Number | 正整数（pt） | 字号，如 `12` |
| `fontColor` | String | hex 颜色 | 字体颜色，如 `"#ff0000"`；也可写作 `foregroundColor` 或 `color` |
| `backgroundColor` | String | hex 颜色 | 背景色，如 `"#fff2cc"`；也可写作 `backColor` |
| `horizontalAlign` | String | `"left"` / `"center"` / `"right"` / `"none"` | 水平对齐 |
| `verticalAlign` | String | `"top"` / `"middle"` / `"bottom"` / `"none"` | 垂直对齐 |
| `wrap` | String | `"overflow"` / `"wrap"` / `"multiLineOverflow"` | 自动换行；也可写作 `textWrap`；`"wrap"` 开启折行显示 |

> ⚠️ `style` 仅对 `sheet.setCell` / `sheet.batchSetCells` 有效；其他命令（如 `sheet.batchGetCells`）只读不写样式。
> ⚠️ `fontFamily` 必须传支持的字体名，不能传字体值；如果字体名不在列表内，不要传 `fontFamily`。

### 支持的字体名

| 字体名 |
|------|
| 宋体 |
| 新宋体 |
| 仿宋 |
| 楷体 |
| 黑体 |
| Arial |
| Arial Black |
| Times New Roman |
| Courier New |
| Tahoma |
| Verdana |

### 示例

```json
// 加粗 + 斜体 + 下划线 + 删除线 + 红字 + 蓝底 + 居中 + 自动换行
{
  "row": 5, "col": 0,
  "value": "长文本内容...",
  "style": {
    "bold": true,
    "italic": true,
    "underline": true,
    "strikethrough": true,
    "fontColor": "#ff0000",
    "backgroundColor": "#0000ff",
    "horizontalAlign": "center",
    "verticalAlign": "middle",
    "wrap": "wrap"
  }
}

// 仅设置自动换行
{ "row": 5, "col": 0, "style": { "wrap": "wrap" } }
```

### 返回值

`style` 设置成功后，命令返回值与普通 setCell/batchSetCells 一致，`version` 会递增。

---

## 富文本 richText

`sheet.setCell` 和 `sheet.batchSetCells` 的每个 cell 均支持可选 `richText` 字段，用于在单个单元格内写入多段不同样式的文本片段。

### 结构

```json
{
  "richText": [
    { "text": "Hello ", "style": { "bold": true, "fontColor": "#ff0000" } },
    { "text": "world", "style": { "underline": true } }
  ]
}
```

富文本片段 `style` 仅支持：`bold`、`italic`、`underline`、`strikethrough`、`fontColor`（也可写作 `foregroundColor` 或 `color`）。

---

## sheet.insertFloatingImage — 插入浮动图片

在指定 Sheet 上插入浮动图片。图片上传由上游服务完成，工具只接收图片 URL。

### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `url` | String | 是 | 图片 URL（由 `popo_doc_upload_local_file` 或 `popo_doc_upload_file_from_url` 上传后返回） |
| `name` | String | 否 | 图片名称，不传则自动生成 |
| `x` | Number | 是 | 左上角 x 坐标 |
| `y` | Number | 是 | 左上角 y 坐标 |
| `width` | Number | 是 | 图片宽度，必须大于 0 |
| `height` | Number | 是 | 图片高度，必须大于 0 |

### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.insertFloatingImage", "payload": {"sheetId": "<SHEET_ID>", "url": "https://example.com/image.png", "x": 20, "y": 20, "width": 160, "height": 100}}'
```

### 返回值

```json
{ "sheetId": "string", "name": "picture-name", "version": 1 }
```

> ⚠️ `url` 来自 `doc_upload_local_file` / `doc_upload_file_from_url` 时常含 `&`/`"`/`{}` 特殊字符，Windows 上必须走 `=@file:` 临时文件方式传 command，规则同 `sheet.setCell` 的 imageUrl 场景。

---

## sheet.deleteFloatingImage — 删除浮动图片

按浮动图片名称删除指定 Sheet 上的浮动图片。`name` 可使用 `sheet.insertFloatingImage` 的返回值。

### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `name` | String | 是 | 浮动图片名称 |

### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.deleteFloatingImage", "payload": {"sheetId": "<SHEET_ID>", "name": "picture-name"}}'
```

### 返回值

```json
{ "sheetId": "string", "name": "picture-name", "version": 1 }
```

---

## sheet.batchGetCells — 批量读取单元格

获取矩形区域内所有单元格的值。只读操作。

### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `row` | Integer | 是 | 起始行（0-based） |
| `col` | Integer | 是 | 起始列（0-based） |
| `rowCount` | Integer | 是 | 行数（>= 1） |
| `colCount` | Integer | 是 | 列数（>= 1） |

### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.batchGetCells", "payload": {"sheetId": "<SHEET_ID>", "row": 0, "col": 0, "rowCount": 5, "colCount": 3}}'
```

### 返回值

```json
{
  "sheetId": "string",
  "row": 0, "col": 0,
  "rowCount": 2, "colCount": 3,
  "indexBase": 0,
  "cells": [
    { "row": 0, "col": 0, "address": "A1", "value": "A1" },
    { "row": 0, "col": 1, "address": "B1", "formula": "=SUM(B1:B2)", "value": null },
    { "row": 1, "col": 2, "address": "C2", "value": 3 }
  ]
}
```

> `cells` 为稀疏数组，只返回有值的单元格；公式拆分到 `formula` 字段，`value` 返回 `null`。

---

## sheet.mergeCells / sheet.unmergeCells — 合并/取消合并单元格

合并或取消合并矩形区域内的单元格。

### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `row` | Integer | 是 | 左上角行（0-based） |
| `col` | Integer | 是 | 左上角列（0-based） |
| `rowCount` | Integer | 是 | 行数（>= 1） |
| `colCount` | Integer | 是 | 列数（>= 1） |

### 示例

```
# 合并
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.mergeCells", "payload": {"sheetId": "<SHEET_ID>", "row": 0, "col": 0, "rowCount": 2, "colCount": 2}}'

# 取消合并
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.unmergeCells", "payload": {"sheetId": "<SHEET_ID>", "row": 0, "col": 0, "rowCount": 2, "colCount": 2}}'
```

### 返回值（mergeCells）

```json
{ "sheetId": "string", "row": 0, "col": 0, "rowCount": 2, "colCount": 2, "version": 1 }
```

### 返回值（unmergeCells）

```json
{ "sheetId": "string", "row": 0, "col": 0, "rowCount": 2, "colCount": 2, "unmergedCount": 1, "version": 1 }
```

> - 1x1 区域为 no-op
> - merge 时区域内第一个非空值移到左上角，其余清空
> - 与已有合并区域部分相交时报错

---

## 工作表管理

### workbook.createSheet — 新建 Sheet

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetName` | String | 是 | Sheet 名称 |
| `index` | Integer | 否 | 插入位置，默认追加到末尾 |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "workbook.createSheet", "payload": {"sheetName": "Sheet2"}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "workbook.createSheet", "payload": {"sheetName": "Sheet3", "index": 0}}'
```

#### 返回值

```json
{ "sheetId": "uuid", "sheetName": "Sheet2", "index": 1, "version": 1 }
```

### workbook.deleteSheet — 删除 Sheet

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | 要删除的 Sheet ID |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "workbook.deleteSheet", "payload": {"sheetId": "<SHEET_ID>"}}'
```

#### 返回值

```json
{ "sheetId": "string", "version": 1 }
```

> 最后一张 Sheet 不可删除。

### workbook.renameSheet — 重命名 Sheet

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `newName` | String | 是 | 新名称 |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "workbook.renameSheet", "payload": {"sheetId": "<SHEET_ID>", "newName": "NewName"}}'
```

#### 返回值

```json
{ "sheetId": "string", "newName": "NewName", "version": 1 }
```

### workbook.copySheet — 复制 Sheet

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | 源 Sheet ID |
| `newTitle` | String | 否 | 新 Sheet 名称，默认沿用原名 |
| `insertIndex` | Integer | 否 | 插入位置，默认紧跟源 Sheet 之后 |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "workbook.copySheet", "payload": {"sheetId": "<SHEET_ID>"}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "workbook.copySheet", "payload": {"sheetId": "<SHEET_ID>", "newTitle": "Copy", "insertIndex": 2}}'
```

#### 返回值

```json
{ "sheetId": "new-uuid", "sourceSheetId": "string", "insertIndex": 2, "version": 1 }
```

### workbook.hideSheet — 隐藏 Sheet

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "workbook.hideSheet", "payload": {"sheetId": "<SHEET_ID>"}}'
```

#### 返回值

```json
{ "sheetId": "string", "version": 1 }
```

> 幂等，已隐藏时 `version` 为 `undefined`。

### workbook.showSheet — 显示 Sheet

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "workbook.showSheet", "payload": {"sheetId": "<SHEET_ID>"}}'
```

#### 返回值

```json
{ "sheetId": "string", "version": 1 }
```

> 幂等，已显示时 `version` 为 `undefined`。

---

## 行列操作

### sheet.insertRows — 插入行

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `startRowIndex` | Integer | 是 | 插入位置（可见行索引）；等于可见行总数时追加到末尾 |
| `count` | Integer | 是 | 插入行数（1-1000） |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.insertRows", "payload": {"sheetId": "<SHEET_ID>", "startRowIndex": 2, "count": 3}}'
```

#### 返回值

```json
{ "sheetId": "string", "startRowIndex": 2, "count": 3, "version": 1 }
```

> 自动更新公式中的行引用，并调整合并区域。

### sheet.deleteRows — 删除行

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `startRowIndex` | Integer | 是 | 起始可见行索引 |
| `count` | Integer | 是 | 删除行数（1-1000） |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.deleteRows", "payload": {"sheetId": "<SHEET_ID>", "startRowIndex": 2, "count": 1}}'
```

#### 返回值

```json
{ "sheetId": "string", "startRowIndex": 2, "count": 1, "version": 1 }
```

> 被删行的公式引用替换为 `#REF!`。

### sheet.insertCols — 插入列

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `startColIndex` | Integer | 是 | 插入位置（可见列索引） |
| `count` | Integer | 是 | 插入列数（1-1000） |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.insertCols", "payload": {"sheetId": "<SHEET_ID>", "startColIndex": 1, "count": 2}}'
```

#### 返回值

```json
{ "sheetId": "string", "startColIndex": 1, "count": 2, "version": 1 }
```

### sheet.deleteCols — 删除列

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `startColIndex` | Integer | 是 | 起始可见列索引 |
| `count` | Integer | 是 | 删除列数（1-1000） |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.deleteCols", "payload": {"sheetId": "<SHEET_ID>", "startColIndex": 1, "count": 2}}'
```

#### 返回值

```json
{ "sheetId": "string", "startColIndex": 1, "count": 2, "version": 1 }
```

### sheet.resizeRows — 调整行高

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `row` | Integer | 是 | 可见行索引 |
| `height` | Integer | 是 | 行高（像素） |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.resizeRows", "payload": {"sheetId": "<SHEET_ID>", "row": 0, "height": 40}}'
```

#### 返回值

```json
{ "sheetId": "string", "row": 0, "height": 40, "version": 1 }
```

### sheet.resizeCols — 调整列宽

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `col` | Integer | 是 | 可见列索引 |
| `width` | Integer | 是 | 列宽（像素） |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.resizeCols", "payload": {"sheetId": "<SHEET_ID>", "col": 1, "width": 120}}'
```

#### 返回值

```json
{ "sheetId": "string", "col": 1, "width": 120, "version": 1 }
```

### sheet.hideRows — 隐藏行

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `row` | Integer | 是 | 起始**可见**行索引 |
| `count` | Integer | 是 | 隐藏行数（1-1000） |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.hideRows", "payload": {"sheetId": "<SHEET_ID>", "row": 3, "count": 2}}'
```

#### 返回值

```json
{ "sheetId": "string", "version": 1 }
```

### sheet.showRows — 显示隐藏行

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `row` | Integer | 是 | 起始**物理**行索引（含隐藏行） |
| `count` | Integer | 是 | 显示行数（1-1000） |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.showRows", "payload": {"sheetId": "<SHEET_ID>", "row": 3, "count": 2}}'
```

#### 返回值

```json
{ "sheetId": "string", "version": 1 }
```

### sheet.hideCols — 隐藏列

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `col` | Integer | 是 | 起始**可见**列索引 |
| `count` | Integer | 是 | 隐藏列数（1-1000） |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.hideCols", "payload": {"sheetId": "<SHEET_ID>", "col": 2, "count": 1}}'
```

#### 返回值

```json
{ "sheetId": "string", "version": 1 }
```

### sheet.showCols — 显示隐藏列

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `col` | Integer | 是 | 起始**物理**列索引（含隐藏列） |
| `count` | Integer | 是 | 显示列数（1-1000） |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.showCols", "payload": {"sheetId": "<SHEET_ID>", "col": 2, "count": 1}}'
```

#### 返回值

```json
{ "sheetId": "string", "version": 1 }
```

---

## 图表操作

### sheet.addChart — 添加图表

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `title` | String | 是 | 图表标题 |
| `domain` | String | 是 | 数据范围，如 `"A1:C5"` |
| `type` | String | 是 | `line` / `pie` / `verticalBar` / `horizontalBar` |
| `location` | Array | 是 | `[x, y, width, height]`（单位是pt，300 pt ≈ 10.58 厘米，一般图表大小设置为400*300，根据数据来调整） |
| `colorScheme` | String | 否 | `s0` ~ `s5`，默认 `s0` |
| `stack` | Boolean | 否 | 默认 `false` |
| `showLabel` | Boolean | 否 | 默认 `false` |
| `transpose` | Boolean | 否 | 默认 `false` |
| `useLegend` | Boolean | 否 | 默认 `true` |
| `useAxis` | Boolean | 否 | 默认 `false` |
| `useCountMode` | Boolean | 否 | 默认 `false` |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.addChart", "payload": {"sheetId": "<SHEET_ID>", "title": "Sales", "domain": "A1:C5", "type": "line", "location": [300, 400, 400, 500]}}'
```

#### 返回值

```json
{ "sheetId": "string", "chartId": "uuid", "version": 1 }
```

### sheet.updateChart — 更新图表

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `chartId` | String | 是 | 图表 ID |
| 其余参数 | -- | 否 | 同 addChart，至少提供一个修改项 |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.updateChart", "payload": {"sheetId": "<SHEET_ID>", "chartId": "<CHART_ID>", "title": "New Title"}}'
```

#### 返回值

```json
{ "sheetId": "string", "chartId": "string", "version": 1 }
```

### sheet.removeChart — 删除图表

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 是 | Sheet ID |
| `chartId` | String | 是 | 图表 ID |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.removeChart", "payload": {"sheetId": "<SHEET_ID>", "chartId": "<CHART_ID>"}}'
```

#### 返回值

```json
{ "sheetId": "string", "chartId": "string", "version": 1 }
```

### sheet.chartList — 列出图表

#### payload 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sheetId` | String | 否 | 过滤指定 Sheet；不填返回所有图表 |

#### 示例

```
popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.chartList", "payload": {}}'

popo-cli popo doc_execute_table docId=<DOC_ID> command='{"type": "sheet.chartList", "payload": {"sheetId": "<SHEET_ID>"}}'
```

#### 返回值

```json
{
  "charts": [
    {
      "sheetId": "string",
      "chartId": "string",
      "title": "销售趋势",
      "domain": "A1:C5",
      "type": "line",
      "location": [0, 0, 6, 4],
      "colorScheme": "s0",
      "stack": false,
      "showLabel": false,
      "transpose": false,
      "useLegend": true,
      "useAxis": false,
      "useCountMode": false
    }
  ]
}
```
