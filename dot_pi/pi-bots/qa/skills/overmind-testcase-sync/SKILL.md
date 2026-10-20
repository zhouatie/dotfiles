---
name: overmind-testcase-sync
description: 通过 mws CLI 自动将测试用例同步录入到网易云音乐 Overmind 任务或需求单（OMMUSIC-xxx）的测试计划中。当用户未提供 Overmind 单据链接时，主动询问。
---

# Overmind Testcase Sync Skill (Overmind 测试用例同步技能)

## 技能定位与触发场景
- 当你在评审需求、拆解测试用例完毕后，需要将用例同步录入到研发效能平台 Overmind（如 `https://music-overmind.hz.netease.com/1/requirement/issues/OMMUSIC-3810064`）的测试计划中；
- 当用户要求“把用例同步到单子上”、“补充用例到 Overmind”、“录入用例”时触发；
- **如果上下文中用户尚未提供 Overmind 任务单链接，主动询问用户**。

---

## 核心工作流 (Workflow)

### Step 1: 提取或主动索取 Overmind 单号 (IssueKey)
1. 从上下文或用户输入中提取单号，如：
   - 链接格式：`https://music-overmind.hz.netease.com/1/requirement/issues/OMMUSIC-3810064`
   - 纯 Key 格式：`OMMUSIC-3810064`
2. **如果上下文中没有找到任何 `OMMUSIC-xxxx` 链接或单号**：
   - **主动向用户询问**：
     > “请问本次任务/需求对应的 Overmind 单子链接是什么（如 `https://music-overmind.hz.netease.com/1/requirement/issues/OMMUSIC-xxxx`）？我将通过 mws 自动把测试用例录入到该单据的测试计划中。”
   - 待用户提供后，再继续执行后续步骤。

---

### Step 2: 查询或创建关联的测试计划 (PlanId)
在 bash 中执行查询：
```bash
mws overmind testcase-plan-get --env online --params '{"refKey":"<issueKey>"}'
```
- 检查返回 JSON 的 `result`：
  - 若 `result.id` 存在（例如 `45426`），则该值即为 `planId`；
  - 若 `result` 为 `null`（说明该需求单尚未创建测试计划），则调用创建接口：
    ```bash
    mws overmind testcase-plan-create --env online --json '{"refKey":"<issueKey>","title":"<issueKey>-测试计划","testPhase":"smoke"}'
    ```
    接口返回的 `result` 即为新生成的 `planId`。

---

### Step 3: 批量录入测试用例到测试计划
获取到 `planId` 后，调用批量添加接口写入用例：
```bash
mws overmind testcase-plan-testcases --env online --json '{
  "planId": <planId>,
  "issueDTOList": [
    {
      "title": "<用例标题，如：4g网络视频不会自动播放>",
      "priority": "P1",
      "issueType": "TESTCASE"
    },
    {
      "title": "<用例标题2>",
      "priority": "P0",
      "issueType": "TESTCASE"
    }
  ]
}'
```

也可以使用单节点结构树写入方式：
```bash
mws overmind testcase-structure-add-node --env online --json '{
  "caseType": "plan",
  "setId": <planId>,
  "leaf": true,
  "issueDTO": {
    "issueType": "TESTCASE_EXE",
    "title": "<用例标题>",
    "priority": "P1"
  }
}'
```

---

### Step 4: 反馈同步成果
录入完成后，向用户汇报：
```markdown
### 📋 测试用例已成功录入 Overmind
- **关联单据**：[<issueKey>](https://music-overmind.hz.netease.com/1/requirement/issues/<issueKey>)
- **测试计划**：https://music-overmind.hz.netease.com/1/requirement/issues/<issueKey>/testing
- **录入用例数**：共 X 条用例
  1. `[P1]` 4g网络视频不会自动播放
  2. `[P0]` ...
```
