# popo_team_remove_robot

将**机器人**从已有群组中移除。

> ⚠️ **机器人不能用 `popo_team_kick_member` 移除**（它不是普通群成员）。必须改用本工具，并通过 `type` 指定机器人类型。
> 普通用户与智能体账号（uid 形如 `xxx@agent.robot.popo.com`）仍然走 `popo_team_kick_member`。

## 命令

```bash
# 移除应用机器人（uid 形如 xxx@app.robot.popo.com → type=1）
popo-cli popo team_remove_robot tid=group_123 robotUid=xxxx@app.robot.popo.com type=1 optType=0

# 撤销「当前上下文中自己刚邀请入群」的机器人（optType=2）
popo-cli popo team_remove_robot tid=group_123 robotUid=xxxx@app.robot.popo.com type=1 optType=2

# 移除自定义机器人（uid 形如 xxx@cus.robot.popo.com → type=2）
popo-cli popo team_remove_robot tid=group_123 robotUid=xxxx@cus.robot.popo.com type=2 optType=0
```

```powershell
# Windows：三个参数都是简单值，直接用双引号包裹即可
popo-cli popo team_remove_robot tid=group_123 robotUid="xxxx@app.robot.popo.com" type=1 optType=0
```

## 请求参数

| 参数名 | 类型 | 必填 | 默认 | 说明 |
|--------|------|------|------|------|
| `tid` | String | **是** | — | 群 ID（通过 `popo_team_search` 获取；用户直接给出纯数字群号时可直接使用） |
| `robotUid` | String | **是** | — | 要移除的机器人 uid。应用机器人为 `xxxx@app.robot.popo.com`，自定义机器人为 `xxxx@cus.robot.popo.com`，通过 `popo_userinfo_search`（`includeRobot=true`）获取 |
| `type` | Integer | **是** | — | 机器人类型。仅允许 `1`、`2`。`1`=应用机器人（`@app.robot.popo.com`），`2`=自定义机器人（`@cus.robot.popo.com`）。**必须与 `robotUid` 的域名一致** |
| `optType` | Integer | **是** | `0` | 操作类型。仅允许 `0`、`2`。`0`=删除（默认；常规删除，只有群主或管理员才能删除），`2`=撤销（撤销**当前上下文中自己**邀请入群的机器人） |

## 响应参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `status` | Integer | `1` 表示成功，其它值表示失败（如 `405` 没有权限操作） |
| `message` | String | 结果描述，成功为 `成功` |

## 使用要点

### 与 popo_team_kick_member 的账号类型分流

判断依据是目标账号 **uid 的域名**：

| 账号类型 | uid 域名 | 移除工具 |
|----------|----------|----------|
| 普通用户 | `xxx@corp.netease.com` / `xxx@mesg.corp.netease.com` | `popo_team_kick_member` |
| 智能体账号（Agent） | `xxx@agent.robot.popo.com` | `popo_team_kick_member` |
| 应用机器人 | `xxx@app.robot.popo.com` | `popo_team_remove_robot`（`type=1`） |
| 自定义机器人 | `xxx@cus.robot.popo.com` | `popo_team_remove_robot`（`type=2`） |

> ⚠️ 不要把 `@agent.robot.popo.com`（智能体账号）误判为机器人而走本工具——它按普通成员处理，用 `popo_team_kick_member`。

### `type` 与 `robotUid` 的对应关系

`type` 必须与 `robotUid` 的域名严格对应，否则移除会失败：

- `robotUid` 以 `@app.robot.popo.com` 结尾 → `type=1`
- `robotUid` 以 `@cus.robot.popo.com` 结尾 → `type=2`

不要仅凭名称里是否含「机器人」判断类型，必须以 uid 域名为准。

### `optType` 选择

- **默认 `0`（删除）**：常规删除路径，只有群主或管理员有权限。
- **`2`（撤销）**：仅适用于「**当前上下文中自己邀请进群的机器人**」。对于自己刚拉错、需要立即撤回的机器人，用 `2` 撤销；其余情况一律用 `0`。

### 移除流程

1. **解析群 ID**：用户提到群名时，先通过 `popo_team_search` 获取 `tid`；用户直接给出纯数字群号时直接作为 `tid`
2. **解析机器人 uid**：用户提到机器人名称时，通过 `popo_userinfo_search`（`includeRobot=true`）获取 uid，并根据 uid 域名确定 `type`（`@app.robot.popo.com`→1，`@cus.robot.popo.com`→2）
3. **确认后调用**：移除机器人属于**破坏性操作**，执行前必须与用户确认；确认后使用 `tid`、`robotUid`、`type`、`optType` 调用 `popo_team_remove_robot`
4. **结果反馈**：`status=1` 时告知用户已把机器人移出群；失败时报告错误信息

### 注意事项

- 移除机器人属于**破坏性操作**，执行前必须与用户确认
- `optType=0`（删除）需要群主或管理员权限；`optType=2`（撤销）仅对当前上下文中自己邀请入群的机器人有效
- 操作失败时**不要**自行重试、也不要改用 `popo_team_kick_member`，将错误信息报告给用户

### 典型场景

```
用户："把 POPO iOS日志分析机器人从群 8809300 里移除"
  ├─ Step 1: 群号为纯数字 → tid=8809300
  ├─ Step 2: popo_userinfo_search("POPO iOS日志分析机器人", includeRobot=true)
  │           → 1613afd5@app.robot.popo.com（@app.robot.popo.com → type=1）
  ├─ Step 3: 与用户确认移除
  └─ Step 4: popo_team_remove_robot(tid=8809300, robotUid=1613afd5@app.robot.popo.com, type=1, optType=0)
```

```
用户："我刚把打包机器人拉进 iOS 群了，撤掉"
  ├─ Step 1: popo_team_search("iOS 群") → tid=<群ID>
  ├─ Step 2: popo_userinfo_search("打包机器人", includeRobot=true)
  │           → 83b5e58e@app.robot.popo.com（应用机器人 → type=1）
  └─ Step 3: 自己刚邀请入群 → optType=2 撤销
              popo_team_remove_robot(tid=<群ID>, robotUid=83b5e58e@app.robot.popo.com, type=1, optType=2)
```
