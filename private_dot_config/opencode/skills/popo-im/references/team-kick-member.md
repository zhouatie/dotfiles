# popo_team_kick_member

从群组中移除成员（支持批量移除）。

## 命令

```bash
# 移除单个成员
popo-cli popo team_kick_member tid=group_123 toUids='["zhangsan@example.com"]'

# 批量移除多个成员
popo-cli popo team_kick_member tid=group_123 toUids='["zhangsan@example.com","lisi@example.com"]'
```

## 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `tid` | String | **是** | 群 ID（通过 `popo_team_search` 获取） |
| `toUids` | List\<String\> | **是** | 被移出群的用户 uid 列表（JSON 数组格式） |

## 响应参数

无返回数据。操作成功时 `popo-cli` 命令正常返回，失败时返回错误信息。

## 使用要点

### 移除流程

1. **解析群 ID**：用户提到群名时，先通过 `popo_team_search` 获取 `tid`
2. **解析成员**：用户提到人名时，先通过 `popo_userinfo_search` 获取邮箱（uid）
3. **调用移除**：使用 `tid` 和成员 uid 列表调用 `popo_team_kick_member`
4. **结果反馈**：告知用户操作结果

### 注意事项

- 只有群主或管理员有权移除成员
- 操作不可撤回，执行前应与用户确认
- 如果 `popo-cli` 返回错误，将错误信息报告给用户

### 典型场景

```
用户："把张三从项目讨论群里移除"
  ├─ Step 1: popo_team_search("项目讨论群") → tid=group_123
  ├─ Step 2: popo_userinfo_search("张三") → zhangsan@example.com（可与 Step 1 并行）
  └─ Step 3: popo_team_kick_member(tid=group_123, toUids='["zhangsan@example.com"]')
```
