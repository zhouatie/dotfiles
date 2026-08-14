-   Unless explicitly requested, do not run linting or type checks, and do not create commits.
-   When a code design decision is uncertain, ask for confirmation before taking action.
-   Unless explicitly requested, do not write compatibility code.
-   Do not read the Figma selection or call Figma tools proactively. Only inspect Figma when the user explicitly asks to inspect the design.
-   When the user asks to inspect Figma, do not hallucinate or draw the UI yourself.

## 子代理调度策略

-   多文件实现任务：先派 scout 侦察（fresh context），再由 planner 出计划并与用户确认，最后派单个 worker 实现。
-   代码评审：派 2-3 个 fresh-context reviewer 并行，角度分别为正确性/测试/简洁性，主会话汇总后再修改。
-   涉及外部库/文档的问题：researcher（外部证据）与 scout（本地代码）并行。
-   同一工作目录同一时间只允许一个 writer 子代理；评审类子代理一律只读。
-   独立可并行的子任务用 async workflowScript 一次发起，不要逐个串行等待。
-   小任务（单文件改动、简单问答）不要分工。
-   父会话始终是决策者和最终汇总者；产品、架构、合并等有歧义的决策向上升级询问用户，不让子代理自行决定。
