# popo_team_update_team_name

修改群组名称。

## 命令

```bash
# 修改群名
popo-cli popo team_update_team_name tid=group_123 tname=新的群名称
```

## 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `tid` | String | **是** | 群 ID（通过 `popo_team_search` 获取） |
| `tname` | String | **是** | 新的群组名称 |

## 响应参数

无返回数据。操作成功时 `popo-cli` 命令正常返回，失败时返回错误信息。

## 使用要点

### 修改流程

1. **解析群 ID**：用户提到群名时，先通过 `popo_team_search` 获取 `tid`
2. **调用修改**：使用 `tid` 和新群名调用 `popo_team_update_team_name`
3. **结果反馈**：告知用户群名已修改

### 注意事项

- 需要有修改群名的权限
- 如果 `popo-cli` 返回错误，将错误信息报告给用户
- 修改群名前应与用户确认新名称

### 典型场景

```
用户："把项目讨论群改名为产品评审群"
  ├─ Step 1: popo_team_search("项目讨论群") → tid=group_123
  └─ Step 2: popo_team_update_team_name(tid=group_123, tname=产品评审群)
```
