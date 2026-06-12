# dotfiles

这是个人 dotfiles 仓库，使用 `chezmoi` 管理跨机器通用配置。

仓库只应该保存可公开同步的个人通用配置。机器私有配置、公司环境配置、AI 工具 token/hook/监控相关配置必须放在本机 local 文件中，不提交到远程。

## 管理范围

当前主要管理：

- Shell 基础配置：`~/.zshrc`
- Git 通用配置：`~/.gitconfig`、`~/.config/git/config`、`~/.config/git/ignore`
- Neovim 通用配置：`~/.config/nvim`
- 终端与工具配置：WezTerm、tmux、Yazi、AeroSpace、Karabiner 等
- 部分静态文件：`proxy.pac`、`tvbox.json`

不管理：

- `.git`、`node_modules`、`.vscode`
- tmux/Neovim/opencode 等插件或依赖产物
- Claude/Codex/OpenCode/Cursor/Raven/Git-AI 的会话、hooks、日志、监控状态
- 本机私有 shell/git/AI provider 配置

## Local 配置

这些文件只存在本机，已被 `.chezmoiignore` 和 `.gitignore` 排除：

- `~/.zshrc.local.pre`
- `~/.zshrc.local`
- `~/.config/git/config.local`
- `~/.config/nvim/lua/plugins/local/**`
- `~/.config/nvim/lua/codemaker.lua`
- `~/.config/nvim/lua/plugins/minuet/codemaker.lua`

`~/.zshrc.local.pre` 用于需要早加载的本机设置，例如 completion 路径、工作目录环境变量。

`~/.zshrc.local` 用于本机命令、代理函数、公司工具 alias、CodeMaker/Claude/Raven/Git-AI 相关命令等。

`~/.config/git/config.local` 用于 Git 身份、公司邮箱、credential、lfs、proxy 等本机配置。不要把 `trace2.*`、`notes.*`、Git-AI socket 或 Raven/Git-AI hook 写回通用配置。

Neovim 的 AI provider、公司 endpoint、token 获取逻辑应放到 ignored local plugin 中，例如：

```text
~/.config/nvim/lua/plugins/local/minuet.lua
```

## 隐私边界

不要提交以下内容：

- `~/.claude/**`
- `~/.codex/**`
- `~/.git-ai/**`
- `~/.raven/**`
- `~/.raven-monitor-home/**`
- `~/.raven-privacy-trash/**`
- `~/.github/hooks/**`
- `~/.cursor/hooks.json`
- `~/.config/opencode/plugins/git-ai.ts`
- 包含 `ANTHROPIC_*`、`OPENAI_*`、`CODEMAKER_*`、access token、auth key、公司 endpoint 的文件

如果误提交过 token/auth key，删除当前文件不等于清除 Git 历史，需要轮换密钥，并视情况重写远程历史。

## 常用命令

初始化：

```bash
chezmoi init git@github.com:zhouatie/dotfiles.git
chezmoi apply
```

查看宿主与源仓库差异：

```bash
chezmoi status
chezmoi diff
```

添加或更新通用配置：

```bash
chezmoi add ~/.zshrc
chezmoi re-add ~/.config/nvim
```

停止管理某个文件：

```bash
chezmoi forget ~/.zshrc
```

应用源仓库配置到宿主：

```bash
chezmoi apply
```

提交前检查敏感关键词：

```bash
rg -n -i "api[_-]?key|token|auth_key|anthropic|openai|codemaker|git-ai|raven|trace2|checkpoint" .
git status --short
git diff --cached --name-status
```

## 静态文件访问

`proxy.pac`、`tvbox.json` 放在这里主要是利用 GitHub raw 文件作为远程静态访问地址。

示例：

```text
https://raw.githubusercontent.com/zhouatie/dotfiles/main/proxy.pac
```
