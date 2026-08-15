---
description: 一键提交代码（commit [自定义 message]）
argument-hint: "[commit message]"
model: langbase/deepseek-v4-flash, deepseek/deepseek-v4-flash
---
提交当前工作区的代码改动。

步骤：
1. 先查看改动概况：`git status --short` 和 `git diff --stat`，了解改了什么
2. 确认改动合理（无敏感信息、无构建产物等无关文件）后执行提交

提交 message：
- 若用户在 `/commit` 后提供了自定义 message（即本模板参数 `$@` 非空），直接使用它
- 否则根据改动内容自动生成符合 Conventional Commits 规范（feat: / fix: / refactor: / docs: / chore: 等）的 message

提交动作：`git add` 相关文件（或 `git add -A`），然后 `git commit -m "<message>"`。

完成后用 `git log -1 --oneline` 汇报提交结果。不要执行 `git push`。
