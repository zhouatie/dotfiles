---
description: 委派任务给指定子代理（use <agent> <task>）
argument-hint: '<agent> <task>'
---

这是一个委派请求。**不要自己执行任务**，按下面两步做：

1. 子代理名称：`$1`
2. 任务内容：`${@:2}`

调用 `subagent` 工具，参数为：

-   `agent`: `$1`
-   `task`: 上述任务内容

等待子代理完成后，把它的输出汇总汇报给我。
