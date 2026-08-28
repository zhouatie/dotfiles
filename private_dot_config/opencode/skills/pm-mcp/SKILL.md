---
name: pm-mcp
description: 通过 Bash 执行 popo-cli pmmcp 系列命令访问网易内部项目管理类平台（易协作 GCP、创意&内容管理 DMP、里程碑 MMP、排期推演 Roadmap、PPJ）的标准四步流程。当用户要查询、修改、创建、操作易协作工单/项目/任务单、排期推演、创意平台/内容管理、里程碑、PPJ的数据，或需要列出某平台可用工具、查看工具入参 schema 时，使用本 skill。即使用户没有显式说"用 pmmcp"，只要意图涉及上述平台的工单管理、任务单查询、项目排期、里程碑计划等，也应触发。
---

# PMMCP 平台查询/操作标准流程

所有操作通过 Bash 执行 `popo-cli pmmcp <工具名> key=value` 命令完成。

> **参数值引号规则（跨平台兼容，禁止使用单引号）**
>
> - 简单值（无空格、无特殊字符）**不加引号**：`key=value`
> - 含空格或特殊字符的值用**双引号**包裹：`key="value with spaces"`
> - JSON 数组/对象用**双引号**包裹，内部双引号使用 `\"` 转义：`key="[\"a\",\"b\"]"`
>
> ```bash
> # ✅ 简单值 — 不需要引号
> popo-cli pmmcp list_tool mcpTarget=gcp gcpHost=pmo.pm.netease.com
>
> # ✅ 数组参数 — 双引号包裹 + 内部 \" 转义
> popo-cli pmmcp tool_schema mcpTarget=mmp gcpHost=pmo.pm.netease.com toolNames="[\"milestonePlan_list\",\"todoTask_add\"]"
>
> # ✅ 嵌套对象 — 双引号包裹 + 内部 \" 转义
> popo-cli pmmcp tool_call mcpTarget=mmp gcpHost=pmo.pm.netease.com toolName=milestonePlan_list arguments="{\"queryReq\":{\"milestoneId\":10000096,\"inland\":true}}"
>
> # ❌ 错误 — 使用单引号（Windows CMD 不支持）
> popo-cli pmmcp tool_schema toolNames='["milestonePlan_list"]'
> ```

> **兜底：HTTP 直传调用**
> 当 `popo-cli pmmcp` 调用后服务端返回类型解析错误（如 `Cannot construct instance of java.util.ArrayList`、`JSON parse error` 等），改用 HTTP 直传方式重试。注意：HTTP 直传的 `tool` 字段使用**完整工具名**（带 `pmmcp_` 前缀），而非 CLI 简写：
> ```bash
> popo-cli call POST /api/v1/open-apis/gateway/appcode/pmmcp/_invoke --body "{\"tool\":\"pmmcp_<工具名>\",\"params\":{...}}"
> ```
> 示例：
> ```bash
> popo-cli call POST /api/v1/open-apis/gateway/appcode/pmmcp/_invoke --body "{\"tool\":\"pmmcp_tool_call\",\"params\":{\"mcpTarget\":\"mmp\",\"gcpHost\":\"pmo.pm.netease.com\",\"toolName\":\"milestonePlan_list\",\"arguments\":{\"queryReq\":{\"milestoneId\":10000096,\"inland\":true}}}}"
> ```

---

## 适用场景

用户要操作下列平台中的数据时使用本 skill：

| 平台               | mcpTarget | 常见用途                           |
| ------------------ | --------- | ---------------------------------- |
| 易协作 GCP（默认） | `gcp`     | 项目、工单、任务单、需求、缺陷管理 |
| 创意&内容管理 DMP  | `dmp`     | 创意素材、内容管理                 |
| 里程碑管理 MMP     | `mmp`     | 里程碑计划、节点跟踪               |
| 排期推演 Roadmap   | `roadmap` | 排期、推演、规划                   |
| PPJ 平台           | `ppj`     | PPJ 项目管理                       |

未明确说哪个平台时，默认 `mcpTarget=gcp`（易协作）。

## 必需参数

调用前必须凑齐两个参数：

- **mcpTarget**：平台标记，按上表选。用户没说就用 `gcp`。
- **gcpHost**：用户的实例域名，例如 `pmo.pm.netease.com`。用户已明示则直接用；**未明示时走下文 Step 1 (`list_instances`) 让用户从清单中选或手动输入**，不要瞎猜或用示例值。不同实例数据不同，错了会调错实例。

## 标准四步流程

分四步：列实例 → 列工具 → 查 schema → 调用。

### Step 1: 列出可用实例域名

用户没明示 `gcpHost` 时，先用 `list_instances` 拿可选实例清单。该调用**不需要** `mcpTarget` 和 `gcpHost`。

```bash
popo-cli pmmcp list_instances
```

返回对象数组，每项含：

- `name`：实例名称
- `domain`：实例域名（即后续 `gcpHost` 的值）

铁律：将可用列表通过 `a2ui_emit` 工具给用户选择（严禁直接返回文本对话），用 `interrupt=True` 等待用户选择：

```python
# select_options = [{"id": item["domain"], "content": f"{item['name']}（{item['domain']}）"} for item in instances]
a2ui_emit(
    card=[
        {
            "surfaceUpdate": {
                "surfaceId": "select-instance",
                "components": [
                    {
                        "id": "root",
                        "component": {"Column": {"children": {"explicitList": ["picker", "confirm-text", "confirm-btn"]}}}
                    },
                    {
                        "id": "picker",
                        "component": {
                            "Dropdown": {
                                "label": {"literalString": "请选择实例"},
                                "value": {"path": "/form/instance"},
                                "options": {"selectOptions": [/* select_options */]}
                            }
                        }
                    },
                    {"id": "confirm-text", "component": {"Text": {"text": {"literalString": "确认"}}}},
                    {"id": "confirm-btn", "component": {"Button": {"child": "confirm-text", "btnType": "Primary", "action": {"name": "select_instance"}}}}
                    # 注意：Button.child 必须是已注册组件的 id 字符串，不能是内联对象
                ]
            }
        },
        {
            "dataModelUpdate": {
                "surfaceId": "select-instance",
                "contents": [{"path": "/form/instance", "valueJson": "\"<select_options[0]['id']>\""}]
                # 默认选中第一个实例，valueJson 填第一个选项的 id 字符串，例如 "\"pmo.pm.netease.com\""
            }
        },
        {"beginRendering": {"surfaceId": "select-instance", "root": "root"}}
    ],
    interrupt=True,
)
```

如果用户未选择，直接点击确认，那么使用第一个实例作为默认值。

用户点击确认后，从 `user_response.values["picker"]` 读取选定的 domain，作为后续步骤的 `gcpHost`。

如果用户在对话中已经明确给出 `gcpHost`，可跳过本步。

### Step 2: 列出可用工具

用 `list_tool` 拿到目标平台支持的工具清单（含 `name` + `description`），用于决定下一步选哪些工具。

```bash
popo-cli pmmcp list_tool mcpTarget=<上表中的值，默认 gcp> gcpHost=<Step 1 选定的域名>
```

返回每个工具的 `name` 和 `description`。根据用户任务从中挑出 1 个或多个候选工具。

### Step 3: 查工具入参 schema

挑好候选工具后，用 `tool_schema` 一次性查一批工具的入参定义。`toolNames` 是字符串数组，可一次传多个名字减少往返。

```bash
popo-cli pmmcp tool_schema mcpTarget=<同上> gcpHost=<同上> toolNames="[\"milestonePlan_list\",\"todoTask_add\"]"
```

返回每个工具的 `name` / `description` / `inputSchema`（JSON Schema 格式的入参定义）。读 `inputSchema` 弄清字段类型、必填项、嵌套结构、字段介绍。

### Step 4: 实际调用工具

按 `inputSchema` 构造 `arguments`，用 `tool_call` 触发真实调用。

```bash
popo-cli pmmcp tool_call mcpTarget=<同上> gcpHost=<同上> toolName=milestonePlan_list arguments="{\"queryReq\":{\"milestoneId\":10000096,\"inland\":true}}"
```

以上 `arguments` 内容为示例，具体结构以 Step 3 拿到的 `inputSchema` 为准，不要凭空捏字段名。

## 使用要点

1. **四步全走**：除非已经在同一会话里跑过对应步骤拿到了所需信息，否则不要跳步直接 `tool_call`，因为工具名和入参格式因平台/版本而异，瞎猜会失败。
2. **缓存重用**：同一会话内已经拿到的 `list_instances` / `list_tool` / `tool_schema` 结果可以直接复用，不要重复问。
3. **批量查 schema**：Step 3 的 `toolNames` 接受数组，一次拿多个工具 schema 比逐个查更省 token。
4. **gcpHost 来源**：用户已明示则直接用；未明示走 Step 1 让用户选/输；不要假设默认值（默认值仅适用于 `mcpTarget`）。
5. **arguments 严格按 schema**：不要照搬示例字段，每个工具入参不同，必须按 Step 3 返回的 `inputSchema` 拼。
6. **mcpTarget 选错的代价**：调错平台会查到无关数据。不确定平台时先和用户确认，不要默默换 target。

## 端到端示例

用户："帮我看下里程碑 ID 10000096 的计划详情。"

推理：里程碑 → `mcpTarget=mmp`；用户没给实例，需先列实例。

```bash
# Step 1
popo-cli pmmcp list_instances
# 返回 [{name:"测试 v40", domain:"pmo.pm.netease.com"}, ...]
# 让用户选，假设用户选了 pmo.pm.netease.com

# Step 2
popo-cli pmmcp list_tool mcpTarget=mmp gcpHost=pmo.pm.netease.com
# 从返回里挑出 milestonePlan_list

# Step 3
popo-cli pmmcp tool_schema mcpTarget=mmp gcpHost=pmo.pm.netease.com toolNames="[\"milestonePlan_list\"]"
# 看到 inputSchema 要求 queryReq.milestoneId / queryReq.inland

# Step 4
popo-cli pmmcp tool_call mcpTarget=mmp gcpHost=pmo.pm.netease.com toolName=milestonePlan_list arguments="{\"queryReq\":{\"milestoneId\":10000096,\"inland\":true}}"
```

最后把工具结果整理后回复用户。
