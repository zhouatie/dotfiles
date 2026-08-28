# popo_message_sticker_quick_reply

以指定机器人身份，对一条**已存在的消息**添加或取消一个系统表情回应（消息表情回应 / message reaction）。

> 这是"对已有消息做表情回应"，不是发送一条新消息。目标消息由 `msgId` + `sessionId` 定位，通常来自 `popo_message_search` 的结果（`msg_id` / `session_id`）。

## 命令

### macOS / Linux

```bash
# 添加表情回应：以机器人 ycy06161931 给某条消息回应"赞"
popo-cli popo message_sticker_quick_reply robotName=ycy06161931 msgId=msg_001 sessionId=123456789 stickerId=THUMBS_UP

# 取消表情回应：opType=2
popo-cli popo message_sticker_quick_reply robotName=ycy06161931 msgId=msg_001 sessionId=123456789 stickerId=THUMBS_UP opType=2

# 指定 robotId 精确匹配（当同名机器人存在多个时）
popo-cli popo message_sticker_quick_reply robotName=ycy06161931 robotId=robot_001 msgId=msg_001 sessionId=123456789 stickerId=ROSE
```

### Windows (PowerShell)

```powershell
# 参数均为简单值（无空格 / 无 JSON），直接传即可，无需临时文件
popo-cli popo message_sticker_quick_reply robotName=ycy06161931 msgId=msg_001 sessionId=123456789 stickerId=THUMBS_UP opType=1
```

## 请求参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `robotName` | String | **是** | — | 机器人全名。⚠️ **必须使用用户精确说出的机器人全名，绝对不要走搜索流程**，直接作为参数传入。需当前登录用户是该机器人的开发者或管理员 |
| `robotId` | String | 否 | — | 机器人 ID（可选，若提供则优先精确匹配，用于同名机器人区分） |
| `msgId` | String | **是** | — | 目标消息 ID。来自 `popo_message_search` 结果的 `msg_id`，**不要手动编造** |
| `sessionId` | String | **是** | — | 目标消息所在会话 ID。来自 `popo_message_search` 结果的 `session_id`，**不要手动编造** |
| `stickerId` | String | **是** | — | 系统表情**枚举名**（当前仅支持 `THUMBS_UP`、`ROSE`、`OK`、`IDEA`、`GET`、`ING`、`ONE`）。由中文表情名映射得到，映射表见 [sticker-enum.md](sticker-enum.md)。⚠️ 传枚举名，不是中文 tag，也不是内部 id |
| `opType` | Integer | 否 | `1` | 操作类型。仅允许 `1`、`2`。`1`=添加表情回应（默认），`2`=取消表情回应 |

## 使用要点

### 操作流程

1. **确定机器人名称**：直接使用用户精确说出的机器人全名作为 `robotName`，不搜索、不转换。
2. **定位目标消息**：`msgId` 与 `sessionId` 必须来自 `popo_message_search` 的结果字段（`msg_id` / `session_id`）。若用户尚未定位到具体消息，先走消息搜索流程。
3. **解析表情枚举名**：把用户口中的中文表情（如"赞""玫瑰""OK""有了"）映射为 `stickerId` 枚举名（见 [sticker-enum.md](sticker-enum.md)，当前仅支持 7 个表情）。若用户想要的表情不在支持范围，说明并建议替代。
4. **判断添加/取消**：默认 `opType=1`（添加回应）；用户明确要"取消/去掉表情回应"时用 `opType=2`。
5. **调用接口**：`popo_message_sticker_quick_reply`。
6. **结果反馈**：告知用户已用某机器人对该消息添加/取消了某表情回应。

### message_search → message_sticker_quick_reply 管道

```
用户："用 ycy06161931 给刚才张三那条'项目进度已更新'的消息点个赞"
  ├─ Step 1: 机器人名 ycy06161931（直接使用，不搜索）
  ├─ Step 2: popo_message_search(query="项目进度已更新") → 取结果 msg_id、session_id
  ├─ Step 3: 中文"赞" → 枚举名 THUMBS_UP（见 sticker-enum.md）
  └─ Step 4: popo_message_sticker_quick_reply(robotName="ycy06161931", msgId=<msg_id>, sessionId=<session_id>, stickerId="THUMBS_UP")
```

```
用户："把那条消息上机器人回应的赞取消掉"
  └─ popo_message_sticker_quick_reply(robotName="ycy06161931", msgId=<msg_id>, sessionId=<session_id>, stickerId="THUMBS_UP", opType=2)
```

## 注意事项

- `sessionType` 由服务端根据 `sessionId` 自动推算（P2P / 群 / 会话 / 文件助手），**无需传**。
- 权限：仅能用**当前登录用户有管理关系**（开发者或管理员）的机器人操作；否则返回无权错误。
- 表情范围：仅支持系统表情，`stickerId` 必须是 [sticker-enum.md](sticker-enum.md) 中的枚举名，非法枚举会被拒绝。
