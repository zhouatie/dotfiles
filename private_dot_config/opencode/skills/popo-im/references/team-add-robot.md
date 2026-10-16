# popo_team_add_robot

将**应用机器人**（uid 形如 `xxx@app.robot.popo.com`）添加到已有群组。

> ⚠️ **应用机器人不能用 `popo_team_invite` 入群**。对应用机器人调用 `popo_team_invite` 会返回 `机器人账户不能加入群组`，必须改用本工具。
> 普通用户与智能体账号（uid 形如 `xxx@agent.robot.popo.com`）仍然走 `popo_team_invite`。

## 命令

```bash
# 添加单个应用机器人
popo-cli popo team_add_robot tid=group_123 robotUids="[\"xxxx@app.robot.popo.com\"]"

# 批量添加多个应用机器人
popo-cli popo team_add_robot tid=group_123 robotUids="[\"aaaa@app.robot.popo.com\",\"bbbb@app.robot.popo.com\"]"
```

```powershell
# Windows：JSON 数组写入 UTF-8 无 BOM 临时文件后用 @file: 传递
popo-cli popo team_add_robot tid=group_123 robotUids=@file:$robotUidsTmpFile
```

## 请求参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `tid` | String | **是** | 群 ID（通过 `popo_team_search` 获取；用户直接给出纯数字群号时可直接使用） |
| `robotUids` | List<String> | **是** | 应用机器人 uid 列表（JSON 数组格式）。uid 形如 `xxxx@app.robot.popo.com`，通过 `popo_userinfo_search`（`includeRobot=true`）获取 |

## 响应参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `status` | Integer | `1` 表示成功，其它值表示失败（如 `405` 没有权限操作） |
| `message` | String | 结果描述，成功为 `成功` |

## 使用要点

### 与 popo_team_invite 的账号类型分流

判断依据是目标账号 **uid 的域名**：

| 账号类型 | uid 域名 | 入群工具 |
|----------|----------|----------|
| 普通用户 | `xxx@corp.netease.com` / `xxx@mesg.corp.netease.com` | `popo_team_invite` |
| 智能体账号（Agent） | `xxx@agent.robot.popo.com` | `popo_team_invite` |
| 应用机器人 | `xxx@app.robot.popo.com` | `popo_team_add_robot` |

- `@app.robot.popo.com` → 应用机器人 → 必须用本工具
- 其余（含 `@agent.robot.popo.com`）→ 用 `popo_team_invite`

不要仅凭名称里是否含「机器人」判断：名称含「机器人」「助手」的账号，可能是智能体账号（可 `team_invite`），也可能是应用机器人（需 `team_add_robot`），必须以 uid 域名区分。

### 添加流程

1. **解析群 ID**：用户提到群名时，先通过 `popo_team_search` 获取 `tid`；用户直接给出纯数字群号时直接作为 `tid`
2. **解析机器人 uid**：用户提到机器人名称时，通过 `popo_userinfo_search`（`includeRobot=true`）获取 uid，并确认 uid 以 `@app.robot.popo.com` 结尾
3. **调用添加**：使用 `tid` 和机器人 uid 列表调用 `popo_team_add_robot`
4. **结果反馈**：`status=1` 时告知用户已把机器人加入群；失败时报告错误信息

### 注意事项

- 只有群主或管理员有权把机器人加入群组
- 机器人必须属于当前操作者有管理权限（开发者或管理员）的机器人
- 操作失败时**不要**自行重试、也不要改用 `popo_team_invite`，将错误信息报告给用户

### 典型场景

```
用户："把 POPO iOS日志分析机器人加到群 8809300"
  ├─ Step 1: 群号为纯数字 → tid=8809300
  ├─ Step 2: popo_userinfo_search("POPO iOS日志分析机器人", includeRobot=true)
  │           → 1613afd5@app.robot.popo.com（@app.robot.popo.com → 应用机器人）
  └─ Step 3: popo_team_add_robot(tid=8809300, robotUids="[\"1613afd5@app.robot.popo.com\"]")
```

```
用户："把打包机上的CodeMaker助手拉进 iOS 群"
  ├─ Step 1: popo_team_search("iOS群") → tid=<群ID>
  ├─ Step 2: popo_userinfo_search("打包机上的CodeMaker助手", includeRobot=true)
  │           → 83b5e58e@agent.robot.popo.com（@agent.robot.popo.com，非 app 域名）
  └─ Step 3: @agent 域名 → 改用 popo_team_invite(tid=<群ID>, inviteList="[\"83b5e58e@agent.robot.popo.com\"]")
```
