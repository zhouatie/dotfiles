---
name: dispatch-bot
description: 调度指定的专业子 Bot (pm, raven, qa, ops, popo) 处理任务，支持同步阻塞等待返回或异步分屏交互。
---

# dispatch-bot 技能使用指南

当你（Master）需要分派任务给专业子 Bot 时，使用本技能提供的命令行接口完成调度。

## 1. 常用命令

### 同步委派并等待结果（默认工作模式）
Master 委派任务时，始终优先采用同步模式。系统将阻塞等待子 Bot 执行完毕，并将子 Bot 的全部输出返回给 Master 进行归纳与汇报：

```bash
~/.config/pi-bots/call-bot.sh --sync <bot-name> "<任务描述>"
```

示例：
```bash
# 委派 popo 查询群成员
~/.config/pi-bots/call-bot.sh --sync popo "查询群 6941659 的群主与管理员"

# 委派 ops 检查预发环境构建
~/.config/pi-bots/call-bot.sh --sync ops "检查 appId 14028 当前在预发环境的部署状态"

# 委派 qa 同步测试用例
~/.config/pi-bots/call-bot.sh --sync qa "分析需求 OMMUSIC-3810670 并生成 P0/P1 测试用例"
```

### 唤起前台独立窗格交互
当用户明确要求自己与子 Bot 直接对话时调用：

```bash
~/.config/pi-bots/call-bot.sh --split <bot-name> [初始提示词]
```
