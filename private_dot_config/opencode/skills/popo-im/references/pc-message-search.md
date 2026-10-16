# popo-cli search messages（PC 客户端本地搜索）

通过 popo-cli daemon 的本地 IPC 通道，调用**当前已登录的 POPO PC 客户端**执行本地大搜（对应大搜"消息"tab 勾选"包含机器人消息"的本地搜索路径，不走服务端搜索）。

> ⚠️ 这是**唯一能覆盖 GRP 等特殊账号会话**以及客户端本地缓存消息的搜索来源。服务端大搜 `popo_message_search` 搜索不到这些会话，因此消息搜索必须**双来源合并**（详见 [workflow.md](workflow.md)）。

## 前置条件

- 本机 popo-cli daemon 已运行且开启本地 IPC（配置项 `daemon.ipc.enabled` 默认开启）。
- POPO PC 客户端已登录，并已作为 `client` 连入 daemon（每账号一实例）。

任一条件不满足时，命令以非零退出并把错误写入 stderr。此时消息搜索应**回退为仅使用服务端 `popo_message_search` 的结果**，不得因为本地来源不可用而整体失败。

## 命令

```bash
# 基本搜索（同步，stdout 输出纯 JSON）
popo-cli search messages 进度

# 指定发送者 / 会话（多个用逗号分隔）
popo-cli search messages 进度 --sender zhangsan@corp.netease.com --session group_123
popo-cli search messages 进度 --sender a@corp.netease.com,b@corp.netease.com

# 只看某类账号发送的消息（按 uid 前缀匹配，跨平台一致）——例如 GRP 账号
popo-cli search messages 进度 --sender-prefix grp.

# 消息类型 / 排序
popo-cli search messages 进度 --type text
popo-cli search messages 进度 --order desc

# 时间范围（秒级 Unix 时间戳，注意与 popo_message_search 的毫秒不同）
popo-cli search messages 进度 --from 1709000000 --to 1710000000

# 范围叠加（恒含"机器人消息"）与条数上限
popo-cli search messages 进度 --scope atme,mypin --count 50

# 多开客户端时指定目标账号
popo-cli search messages 进度 --uid liuyawei@corp.netease.com

# 管道裁剪（推荐）
popo-cli search messages 进度 | jq '{truncated, messages: [.messages[]? | {msgId, sessionId, sessionType, senderId, content, timestamp}]}'
```

## 请求参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `<keyword>` | String | - | 搜索关键词（必填，位置参数） |
| `--sender <uids>` | String | - | 按发送者 uid 过滤，逗号分隔（精确匹配） |
| `--sender-prefix <prefix>` | String | - | 按发送者 uid **前缀**过滤（如 `grp.`），只返回匹配账号发送的消息；mac 与 Windows 行为一致 |
| `--session <ids>` | String | - | 按会话 ID 过滤，逗号分隔 |
| `--type <type>` | String | `all` | 消息类型：`all` \| `text` \| `file` |
| `--order <order>` | String | `default` | 结果排序：`default` \| `asc` \| `desc` |
| `--scope <scopes>` | String | - | 在"机器人消息"基础上叠加范围：`atme,mypin,allpin,exited` |
| `--from <ts>` | Integer | - | 时间下界，**秒**级 Unix 时间戳 |
| `--to <ts>` | Integer | - | 时间上界，**秒**级 Unix 时间戳 |
| `--count <n>` | Integer | `20` | 最大条数，上限 `100` |
| `--async` | Flag | - | 异步提交，立即返回 `{"requestId":"..."}`，再用 `popo-cli ipc wait <requestId>` 取回 |
| `--uid <uid>` | String | - | 多开客户端时指定目标账号 |
| `--timeout <ms>` | Integer | `10000` | 同步超时（毫秒） |

## 响应参数

```json
{
  "truncated": false,
  "messages": [
    {
      "msgId": "msg_001",
      "msgSerial": 123,
      "sessionId": "session_001",
      "sessionType": 1,
      "msgSubType": 0,
      "senderId": "sender@corp.netease.com",
      "content": "项目进度已更新",
      "timestamp": 1709000000000,
      "matchReason": "content"
    }
  ]
}
```

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `truncated` | Boolean | 结果超过体积上限被截断时为 `true`（可减少 `--count` 或收窄时间范围重试） |
| `messages` | List\<Message\> | 命中的消息列表 |

### Message 结构

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `msgId` | String | 消息 ID |
| `msgSerial` | Long | 消息序号 |
| `sessionId` | String | 会话 ID |
| `sessionType` | Integer | 会话类型 |
| `msgSubType` | Integer | 消息子类型 |
| `senderId` | String | 发送者 uid |
| `content` | String | 消息内容（纯文本摘要） |
| `timestamp` | Long | 消息时间戳（**毫秒**，统一用于合并排序） |
| `matchReason` | String | 命中原因 |

## 错误码（stderr / JSON）

| 错误 | 含义 | 处理 |
|------|------|------|
| `IPC_DAEMON_OFFLINE` / 无法连接 | daemon 未运行或 IPC 未开启 | 回退为仅服务端搜索 |
| `ERR_NO_CLIENT` | 没有 POPO 客户端连入 daemon | 回退为仅服务端搜索 |
| `ERR_NO_SUCH_INSTANCE` | 多开且未指定 / 指定账号不存在 | 指定 `--uid` 重试或回退 |
| `ERR_TIMEOUT` | 客户端未在超时内返回 | 可增大 `--timeout` 重试或回退 |
| `ERR_PROTO` | 参数非法 | 检查参数后重试 |

> 时间单位差异：本命令的 `--from` / `--to` 是**秒**，返回的 `timestamp` 是**毫秒**；`popo_message_search` 的 `timeStart` / `timeEnd` 与 `t_msg` 均为**毫秒**。合并前需统一为毫秒。

## 定位「搜不到 GRP 消息」的原因

本命令的输出本身即可区分三类原因，无需查日志。用户反馈搜不到时，先看命令的 stderr / JSON，并按下表归类后告知用户：

| CLI 输出 | 结论 | 归属 | 下一步 |
|----------|------|------|--------|
| stderr 提示 `cannot connect to the popo-cli daemon IPC endpoint` / `popo-cli daemon start` | 守护进程未运行或 IPC 未开启 | ① 守护进程 | 启动 daemon：`popo-cli daemon start` |
| `{"ok":false,"error":{"code":"ERR_NO_CLIENT"}}` | daemon 正常，但没有 POPO 客户端连入 | ① 守护进程 | 确认 PC 客户端已登录（在登录页启动时 IPC 不会连上，登录后重启客户端） |
| `{"ok":false,"error":{"code":"ERR_NO_SUCH_INSTANCE"}}` | 多开且未指定账号，或指定账号不在线 | ① 守护进程 | 用 `--uid <当前账号>` 指定 |
| `{"ok":false,"error":{"code":"ERR_TIMEOUT"}}` | 请求已到客户端，但客户端未在超时内返回 | ② PC 客户端调用 | 增大 `--timeout` 重试；持续超时则是客户端异常 |
| `{"ok":false,"error":{"code":"ERR_PROTO"}}` | 客户端处理失败（参数非法或本地搜索服务异常） | ② PC 客户端调用 | 检查参数；否则为客户端异常 |
| `{"truncated":false,"messages":[]}`（`ok` 为真但 0 条） | 请求到达客户端且成功，本地库无命中 | ③ 真的没结果 | 放宽条件自检后仍是 0 条即确认为无结果 |

> - **① / ② 时请勿下结论「没有该消息」**：本地来源不可用时，工作流会回退为仅服务端结果，而服务端本身就搜不到 GRP 会话，表现同样是「没有 GRP 结果」。必须先修通通道再判断。
> - **③ 的自检**：去掉 `--scope` / `--from` / `--to`、增大 `--count`、换更短的关键词再搜；仍为 0 条才是真的没有匹配消息。
> - 回复用户时请带上具体错误码（如 `ERR_NO_CLIENT`），便于对方区分是通道问题还是确实没有结果。
