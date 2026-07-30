---
name: hermes
description: 当用户在 pi-agent 中显式输入 `/hermes ...` 时使用。把 `/hermes` 后面的请求，以及必要的当前对话上下文，转交给 Hermes CLI 执行；这相当于在 pi-agent 里变相调用 `hermes chat`。不要因为普通请求自动触发，必须看到 `/hermes` 或用户明确说“调用 Hermes”。
---

# Hermes Bridge

这个 skill 是 pi-agent 到 Hermes 的通用桥接器。

用户输入：

```text
/hermes <给 Hermes 的请求>
```

含义：把 `<给 Hermes 的请求>` 交给 Hermes Agent 处理，并把 Hermes 的最终回复返回给用户。它不是只用于 Obsidian；记录笔记只是其中一个用法。

## 固定命令

优先使用通用脚本：

```bash
python3 /Users/zhoushitie/.config/pi/skills/hermes/scripts/hermes_chat.py <<'EOF'
<转交给 Hermes 的完整请求和必要上下文>
EOF
```

脚本内部调用：

```bash
hermes chat -Q --source tool -q '<prompt>'
```

可选增强：

```bash
python3 /Users/zhoushitie/.config/pi/skills/hermes/scripts/hermes_chat.py \
  --skills obsidian \
  --toolsets file,terminal,skills \
  --timeout 180 <<'EOF'
<转交给 Hermes 的完整请求和必要上下文>
EOF
```

## 调用规则

1. 仅当用户显式输入 `/hermes` 或明确要求“调用 Hermes”时启用。
2. 把 `/hermes` 后面的内容当作用户想让 Hermes 做的真实请求。
3. 如果用户说“上面这个 / 上文 / 这个 prompt / 这份文档 / 刚才的内容”，需要从当前 pi-agent 对话中提取最近相关上下文，一起转交给 Hermes；不要只转发这句话。
4. 如果请求需要文件、Obsidian、系统命令、搜索或长期记忆，交给 Hermes 做；pi-agent 不要自行替代 Hermes 执行。
5. 不要把 API key、token、Cookie、密码等秘密转交或写入笔记；发现明显秘密时先省略或标注“已省略敏感信息”。
6. Hermes 执行后，把 Hermes 的最终输出摘要给用户；如果 Hermes 返回了文件路径、错误、阻塞原因，要如实转述。

## 请求封装格式

传给脚本的 stdin 建议使用以下 Markdown 格式：

```markdown
# pi-agent 调用 Hermes

## 用户 /hermes 指令
/hermes <用户原文>

## 给 Hermes 的任务
<去掉 /hermes 后的任务描述>

## pi-agent 当前上下文
<当用户引用“上面/刚才/这份文档”时，填入相关上下文；否则可省略>

## pi-agent 备注
<可选：说明上下文截取范围、文件路径、约束等>
```

## 常见用法

### 1. 通用问答 / 操作

用户：

```text
/hermes 帮我查一下当前机器磁盘空间
```

执行：

```bash
python3 /Users/zhoushitie/.config/pi/skills/hermes/scripts/hermes_chat.py <<'EOF'
# pi-agent 调用 Hermes

## 用户 /hermes 指令
/hermes 帮我查一下当前机器磁盘空间

## 给 Hermes 的任务
帮我查一下当前机器磁盘空间。
EOF
```

### 2. 记录 Obsidian 笔记

用户：

```text
/hermes 请帮我记录上面这个prompt、文档内容，到笔记中
```

执行时建议显式加载 Obsidian skill 和文件工具：

```bash
python3 /Users/zhoushitie/.config/pi/skills/hermes/scripts/hermes_chat.py \
  --skills obsidian \
  --toolsets file,terminal,skills \
  --timeout 180 <<'EOF'
# pi-agent 调用 Hermes

## 用户 /hermes 指令
/hermes 请帮我记录上面这个prompt、文档内容，到笔记中

## 给 Hermes 的任务
请把下面的 prompt / 文档内容整理成 Markdown 笔记，写入 Obsidian Vault：
/Users/zhoushitie/My/Obsidian/AtieVault

默认写入目录：
00 Inbox/pi-agent/

要求：
- 自动生成清晰标题
- 文件名格式：YYYY-MM-DD HHmm - 标题.md
- frontmatter 包含 source: pi-agent、created_at、tags: [pi-agent]
- 保留原始 prompt / 文档内容，必要时整理摘要、标题、待办
- 返回最终文件路径

## pi-agent 当前上下文
<这里填入当前会话上方真实需要记录的 prompt 和文档内容>
EOF
```

### 3. 只做 dry-run 检查

```bash
python3 /Users/zhoushitie/.config/pi/skills/hermes/scripts/hermes_chat.py --dry-run <<'EOF'
/hermes 你好
EOF
```

## 脚本参数

```bash
python3 /Users/zhoushitie/.config/pi/skills/hermes/scripts/hermes_chat.py --help
```

常用参数：

- `--skills obsidian`：预加载 Hermes skill，可逗号分隔。
- `--toolsets file,terminal,skills`：限制 Hermes 工具集，可逗号分隔。
- `--timeout 180`：等待 Hermes 完成的秒数。
- `--dry-run`：只打印将调用的命令和 prompt，不实际调用 Hermes。

## 和 `hermes_obsidian_note.py` 的关系

`hermes_obsidian_note.py` 是早期的 Obsidian 专用封装，仍保留兼容。新请求优先使用 `hermes_chat.py`；只有在你明确只想“记录 Obsidian 笔记”且不需要通用对话时，才使用旧脚本。
