# popo_team_info_query

查询群详情信息。支持两种查询类型：

- **群公告**（`type=1`）：查询群公告内容和发布时间
- **群成员列表**（`type=2`）：查询群组中的所有成员信息（姓名、邮箱、所属组织）

> ⚠️ **注意**：`type` 参数为必填，单次调用只能查询一种类型（公告或成员）。如需同时获取公告和成员，需分别调用两次。

## 命令

```bash
# 查询群公告
popo-cli popo team_info_query tid=1000114924 type=1

# 查询群成员列表
popo-cli popo team_info_query tid=1000114924 type=2
```

## 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `tid` | String | **是** | 群 ID（通过 `popo_team_search` 获取） |
| `type` | Integer | **是** | 查询类型：`1` 群公告，`2` 群成员列表 |

## 响应参数

### 顶层结构

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `status` | Integer | 状态码（`1` 成功） |
| `message` | String | 状态信息 |
| `data` | Object | 查询结果数据 |

### data 结构

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `tid` | String | 群 ID |
| `type` | Integer | 查询类型（回显） |
| `announcement` | Object \| null | 群公告信息（`type=1` 时有值，`type=2` 时为 null） |
| `members` | Array \| null | 群成员列表（`type=2` 时有值，`type=1` 时为 null） |

### announcement 结构

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `board` | String | 群公告纯文本内容 |
| `timeTag` | Long | 公告发布时间（秒级 Unix 时间戳） |

### members[] 结构

| 参数名 | 类型 | 说明 | 用途 |
|--------|------|------|------|
| `name` | String | 用户姓名 | 展示成员身份 |
| `nick` | String | 用户昵称 | 辅助确认 |
| `email` | String | 用户邮箱（POPO 账号） | 作为 uid 用于后续操作（如发送消息、邀请入群） |
| `departmentName` | String | 所属组织/部门 | 按部门分组展示 |

## 响应示例

### 查询群公告（type=1）

```json
{
    "status": 1,
    "message": "成功",
    "data": {
        "tid": "1000114924",
        "type": 1,
        "announcement": {
            "board": "这是一个群公告",
            "timeTag": 1780653756
        },
        "members": null
    }
}
```

### 查询群成员列表（type=2）

```json
{
    "status": 1,
    "message": "成功",
    "data": {
        "tid": "1000114924",
        "type": 2,
        "announcement": null,
        "members": [
            {
                "name": "任忠",
                "nick": "任忠",
                "email": "renzhong01@corp.netease.com",
                "departmentName": "效率工程部-云协作产品中心-AI工具组"
            },
            {
                "name": "刘六六(刘亚威)",
                "nick": "刘六六(刘亚威)",
                "email": "liuyawei@corp.netease.com",
                "departmentName": "效率工程部-云协作产品中心-POPO组"
            },
            {
                "name": "李思雨",
                "nick": "李思雨",
                "email": "lisiyu03@corp.netease.com",
                "departmentName": "效率工程部-云协作产品中心-云文档与多维表组"
            }
        ]
    }
}
```

## 使用要点

### 典型场景

#### 场景一：查看群成员列表

```
用户：「看一下「POPO CLI 互助交流群」里都有哪些人，按部门分组列一下」
  ├─ Step 1: popo_team_search("POPO CLI 互助交流群") → tid=1000114924
  └─ Step 2: popo_team_info_query(tid=1000114924, type=2) → 获取成员列表
       └─ 按 departmentName 字段分组展示成员
```

#### 场景二：查看群公告

```
用户：「看看项目讨论群的群公告写了什么」
  ├─ Step 1: popo_team_search("项目讨论群") → tid=group_123
  └─ Step 2: popo_team_info_query(tid=group_123, type=1) → 获取公告内容
       └─ 展示 board 字段（纯文本）内容
```

#### 场景三：同时获取公告和成员

```
用户：「帮我看看项目群的公告和成员信息」
  ├─ Step 1: popo_team_search("项目群") → tid=group_123
  ├─ Step 2: popo_team_info_query(tid=group_123, type=1) → 公告（与 Step 3 并行）
  └─ Step 3: popo_team_info_query(tid=group_123, type=2) → 成员（与 Step 2 并行）
       └─ 合并展示：先公告，再成员列表
```

### 成员列表展示建议

- **按部门分组**：以 `departmentName` 字段为分组键，同一部门的成员归到一组
- **部门层级展示**：部门名称中的 `-` 为层级分隔符，可提取最后一段作为简称
- **成员排序**：同部门内按 `name` 字母/拼音排序
- **汇总信息**：开头展示总人数、部门数

### 注意事项

- `type` 参数为必填，单次调用只能查询一种类型。如需同时获取公告和成员，需分别发起两次调用（可并行执行）
- 群不存在或当前用户不在群中时，`popo-cli` 返回错误，将错误信息报告给用户
- `announcement` 为 null 时表示该群暂无公告
- `members` 为 null 时表示当前查询类型不是成员列表
- 成员列表中的 `email` 可直接作为 uid 用于后续的 POPO 操作（如发送消息、邀请入群等），无需再次通过 `popo_userinfo_search` 解析
