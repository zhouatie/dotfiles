# popo_team_create

创建群组。需要提供当前用户 uid、群成员列表（至少 1 人），可选群名和头像。

> **前置步骤**：创建群组前必须先调用 `popo_team_current_user_info` 获取当前用户 uid，作为 `uid` 参数传入。

> ⚠️ **`uid` 与 `uidList` 的区别（必读）**
>
> | 参数 | 含义 | 放谁 |
> |------|------|------|
> | `uid` | 群创建者（当前用户），**必填** | 始终且仅填当前用户自己的 uid |
> | `uidList` | 被邀请入群的**其他人** | 只填其他人的 uid，**禁止包含当前用户** |
>
> **创建者（`uid`）会自动成为群成员，无需重复添加到 `uidList`。**
>
> 当用户说"把我也拉进去"、"我也要在群里"、"帮我和张三建个群"等包含"我"的表述时：
> - ✅ 正确理解：用户是群创建者，已通过 `uid` 参数自动入群，**无需任何额外处理**
> - ❌ 错误做法：将当前用户 uid 加入 `uidList` — 这会导致 `uid` 参数被遗漏或语义混淆

## 命令

```bash
# 先获取当前用户 uid
popo-cli popo team_current_user_info
# 返回示例：{ "uid": "myself@example.com", ... }

# 基本创建（从会话列表创建）
popo-cli popo team_create uid=myself@example.com uidList='["zhangsan@example.com","lisi@example.com"]' type=1

# 指定群名
popo-cli popo team_create uid=myself@example.com name=项目讨论群 uidList='["zhangsan@example.com","lisi@example.com"]' type=1

# 从单聊会话创建
popo-cli popo team_create uid=myself@example.com uidList='["zhangsan@example.com"]' type=2

# 指定创建者和头像
popo-cli popo team_create uid=myself@example.com name=项目群 uidList='["zhangsan@example.com","lisi@example.com"]' type=1 creator=admin@example.com photo_url=https://example.com/avatar.png
```

## 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `uid` | String | **是** | 当前用户 uid（通过 `popo_team_current_user_info` 获取）。创建者自动入群，**不要**把此 uid 放入 `uidList` |
| `name` | String | 否 | 群组名称（不传则系统自动生成） |
| `uidList` | List\<String\> | **是** | **其他**群成员 uid 数组（JSON 数组格式）。**禁止包含当前用户 uid** |
| `photo_url` | String | 否 | 群组头像 URL |
| `type` | Integer | **是** | 创建来源：`1` 会话列表，`2` 单聊会话 |
| `creator` | String | 否 | 创建者 uid |
| `headPicExtStr` | String | 否 | 头像扩展信息（JSON 字符串） |

## 响应参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `tid` | String | 群组 ID |
| `name` | String | 群组名称 |
| `photoUrl` | String | 群组头像 URL |
| `needConfirm` | List\<Member\> | 受管控人员（非邀请者下属） |
| `extUsers` | List\<Member\> | 受管控人员（邀请者下属，但 20 人以上群数量超上限） |
| `passNum` | Integer | 实际入群人员数量 |
| `applyType` | Integer | 加群方式：`1` 主动申请，`2` 被动申请 |

### Member 结构

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `uid` | String | 用户 uid |
| `name` | String | 用户姓名 |
| `headPic` | String | 用户头像 |

### 关键提取路径

| 路径 | 类型 | 说明 | 用途 |
|------|------|------|------|
| `tid` | String | 新创建的群组 ID | 后续群操作（邀请成员、修改群名等）的 `tid` 参数 |
| `passNum` | Integer | 实际入群人数 | 告知用户实际入群情况 |
| `needConfirm` | List | 需审批人员 | 告知用户哪些人需要审批 |

## 响应示例

```json
{
  "tid": "group_456",
  "name": "项目讨论群",
  "photoUrl": "https://example.com/avatar.png",
  "needConfirm": [],
  "extUsers": [],
  "passNum": 2,
  "applyType": 2
}
```

## 使用要点

### 创建流程

1. **获取当前用户 uid**：调用 `popo-cli popo team_current_user_info`，从返回结果中提取 `uid` 字段
2. **解析用户意图**：提取群名（可选）和成员列表
3. **成员解析**：用户提到的人名需先通过 `popo_userinfo_search` 搜索获取邮箱（uid），**不要猜测邮箱**（可与步骤 1 并行执行）
4. **过滤当前用户**：从解析后的成员列表中**移除当前用户 uid**（如果存在）。当前用户通过 `uid` 参数自动入群，放入 `uidList` 是错误的
5. **调用创建**：将当前用户 uid 作为 `uid` 参数，过滤后的其他成员列表作为 `uidList` 参数，调用 `popo_team_create`
6. **结果反馈**：告知用户群创建结果，包括群名、群 ID、实际入群人数

### 管控人员处理

- `needConfirm` 不为空时：告知用户这些人需要审批确认才能入群
- `extUsers` 不为空时：告知用户这些人因群数量限制暂未入群
- 两者均为空且 `passNum` 等于请求人数时：所有人已成功入群

### 典型场景

```
用户："帮我创建一个群，把张三和李四拉进来"
  ├─ Step 1: popo_team_current_user_info() → myself@example.com
  ├─ Step 2: popo_userinfo_search("张三") → zhangsan@example.com（可与 Step 1 并行）
  ├─ Step 3: popo_userinfo_search("李四") → lisi@example.com（可与 Step 1、2 并行）
  └─ Step 4: popo_team_create(uid="myself@example.com", uidList='["zhangsan@example.com","lisi@example.com"]', type=1)
                                ↑ 当前用户，自动入群         ↑ 只放其他人
```

```
用户："帮我和张三、李四建一个群"（用户说"我和..."，暗示自己也要在群里）
  ├─ Step 1: popo_team_current_user_info() → myself@example.com
  ├─ Step 2: popo_userinfo_search("张三") → zhangsan@example.com
  ├─ Step 3: popo_userinfo_search("李四") → lisi@example.com
  └─ Step 4: popo_team_create(uid="myself@example.com", uidList='["zhangsan@example.com","lisi@example.com"]', type=1)
       ✅ "我"已通过 uid 参数入群，uidList 中只放张三和李四
       ❌ 错误：uidList='["myself@example.com","zhangsan@example.com","lisi@example.com"]'
```

```
用户："建个群把我也拉进去，还有张三"
  ├─ Step 1: popo_team_current_user_info() → myself@example.com
  ├─ Step 2: popo_userinfo_search("张三") → zhangsan@example.com
  └─ Step 3: popo_team_create(uid="myself@example.com", uidList='["zhangsan@example.com"]', type=1)
       ✅ "把我也拉进去"不需要额外处理，创建者自动在群里
```
