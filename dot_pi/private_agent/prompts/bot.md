---
description: 调度本地独立子 Bot（/bot [bot-name] <任务>）
argument-hint: "[bot-name] <任务>"
---
这是本地独立子 Bot 调度请求。**严禁自己执行该任务**，严禁进行代码分析、文件检索、参数探测或质疑用户需求。

请立即调用 bash 工具单次运行以下命令完成派发：
```bash
~/.config/pi-bots/call-bot.sh "$@"
```

命令执行后，根据输出直接向用户汇报已启动，不得在当前会话中阻塞等待。
