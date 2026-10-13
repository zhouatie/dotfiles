-   Unless explicitly requested, do not run linting, type checks, or jest tests, and do not create commits.
-   When a code design decision is uncertain, ask for confirmation before taking action.
-   Unless explicitly requested, do not write compatibility code.
-   Do not read the Figma selection or call Figma tools proactively. Only inspect Figma when the user explicitly asks to inspect the design.
-   When the user asks to inspect Figma, do not hallucinate or draw the UI yourself.
-   不要主动帮我提交代码，除非我要求你帮我提交代码。

## 子代理调度策略

-   多文件实现任务：先派 scout 侦察（fresh context），再由 planner 出计划并与用户确认，最后派单个 worker 实现。
-   代码评审：派 2-3 个 fresh-context reviewer 并行，角度分别为正确性/测试/简洁性，主会话汇总后再修改。
-   涉及外部库/文档的问题：researcher（外部证据）与 scout（本地代码）并行。
-   同一工作目录同一时间只允许一个 writer 子代理；评审类子代理一律只读。
-   独立可并行的子任务用 async workflowScript 一次发起，不要逐个串行等待。
-   小任务（单文件改动、简单问答）不要分工。
-   父会话始终是决策者和最终汇总者；产品、架构、合并等有歧义的决策向上升级询问用户，不让子代理自行决定。

### 本地专家子 Bot (Pi-Bots) 调度协议

在 `~/.config/pi-bots/` 目录下预置了一批专项领域的独立专家 Bot。当用户要求调用特定 Bot（如 "让 raven 开发"、"让 qa 写用例"、"让 pm 把控"）或任务明显属于某专业领域时，使用 `bash` 工具调度执行：

```bash
~/.config/pi-bots/call-bot.sh <bot-name> "<任务内容与上下文>"
```

**可用专家列表与实际职责分工（已严格对齐各自 AGENTS.md）**：

-   **raven (SDD 前端研发专家)**:
    -   以 Spec-Driven (SDD) 标准流程驱动日常需求开发与复杂前端功能实现。
    -   精通 ravenspec 规范制定、Figma 设计稿转原型 (`raven-figma-to-design`)、`design.md` 方案对齐与 `sdd-apply-change` 编码落地。
-   **pm (资深产品经理 · 需求与交付把控)**:
    -   把控端到端 SDLC 研发生命周期与需求结构化拆解（User Story、AC 验收标准）。
    -   **核心前置门禁 (Readiness Gate)**：严格核验研发前置依赖，尤其是 **UI 视觉稿依赖把关**（涉及界面改动若缺 Figma 视觉稿将主动触发阻断确认）。
    -   技术方案评审把关（文案/数值展示口径、网络/空态异常兜底、依赖上线顺序）。
-   **qa (测试开发与质量保障专家)**:
    -   需求用例矩阵设计，并通过 `mws` 工具链自动同步录入 Overmind 测试计划 (`overmind-testcase-sync`)。
    -   提测白盒与自动化验证（单测运行、`playwright-browser` E2E 端到端回归）与黑盒验收 Checklist 梳理。
    -   缺陷管理定位与出具正式【QA 验收通过报告】。
-   **ops (资深运维工程师 · 打包构建与环境专家)**:
    -   精通网易云音乐 Febase 前端研发平台及 `mws febase` 工具链 (`febase-build-deploy`)。
    -   负责 Febase 应用识别、测试/预发环境域名申请与分配 (`sprint-env-create`)、云端流水线打包构建 (`sprint-deploy`) 与构建日志诊断排查 (`deploy-logs`)。
-   **popo (POPO 办公协作与 IM 专家)**:
    -   精通 `popo-cli` 工具链，支持单聊/群聊消息、文件与图片发送。
    -   消息全文检索（服务端与 PC 客户端双端合并搜索并还原上下文）。
    -   员工信息检索 (`userinfo_search`)、群组管理（建群/拉人/改公告）与 POPO 在线文档/多维表格读写 (`popo-doc-read`)。

**调度与汇报规范**：

1. 传入的任务描述应包含当前任务的具体文件路径、报错信息或需求细节。
2. 子 Bot 执行完成后，主 Agent 负责汇总子 Bot 的输出，向用户呈现核心结论与后续行动建议。

## 文件搜索与代码定位规范

-   代码检索优先使用工具提供的 `grep`（或终端中的 `rg`），文件查找优先使用 `find`（或终端中的 `fd`）。
-   禁止在 bash 中使用未做目录排除的原生 `grep -rn` 与 `find .`，避免扫描 `bundle/`、`dist/`、`.pi/` 等超大或缓存目录导致超时。
