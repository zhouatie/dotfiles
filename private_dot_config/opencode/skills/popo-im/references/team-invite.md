# popo_team_invite

邀请新成员加入已有群组。

## 命令

```bash
# 邀请单个成员
popo-cli popo team_invite tid=group_123 inviteList='["zhangsan@example.com"]'

# 邀请多个成员
popo-cli popo team_invite tid=group_123 inviteList='["zhangsan@example.com","lisi@example.com"]'

# 附带邀请原因
popo-cli popo team_invite tid=group_123 inviteList='["zhangsan@example.com"]' text=项目协作需要
```

## 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `tid` | String | **是** | 群 ID（通过 `popo_team_search` 获取） |
| `inviteList` | List\<String\> | **是** | 邀请成员 uid 列表（JSON 数组格式） |
| `text` | String | 否 | 邀请原因 |

## 响应参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `type` | Integer | 加群情况：`0` 直接入群，`1` 需要申请 |
| `needConfirm` | List\<Member\> | 受管控人员（非邀请者下属） |
| `extUsers` | List\<Member\> | 受管控人员（邀请者下属，但 20 人以上群数量超上限） |
| `passNum` | Integer | 入群人员数量 |
| `tid` | String | 群 ID |
| `applyType` | Integer | 加群方式 |

### Member 结构

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `uid` | String | 用户 uid |
| `name` | String | 用户姓名 |
| `headPic` | String | 用户头像 |

## 响应示例

```json
{
  "type": 0,
  "needConfirm": [],
  "extUsers": [],
  "passNum": 1,
  "tid": "group_123",
  "applyType": 2
}
```

## 使用要点

### 邀请流程

1. **解析群 ID**：用户提到群名时，先通过 `popo_team_search` 获取 `tid`
2. **解析成员**：用户提到人名时，先通过 `popo_userinfo_search` 获取邮箱（uid）
3. **调用邀请**：使用 `tid` 和成员 uid 列表调用 `popo_team_invite`
4. **结果反馈**：根据 `type` 字段告知用户邀请结果

### 结果处理

- `type=0`：成员已直接入群
- `type=1`：已发送入群申请，等待审批
- `needConfirm` 不为空：这些人需要额外确认
- `passNum`：实际成功入群的人数

### 典型场景

```
用户："把王五加到项目讨论群里"
  ├─ Step 1: popo_team_search("项目讨论群") → tid=group_123
  ├─ Step 2: popo_userinfo_search("王五") → wangwu@example.com（可与 Step 1 并行）
  └─ Step 3: popo_team_invite(tid=group_123, inviteList='["wangwu@example.com"]')
```
