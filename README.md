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
- `~/.config/opencode/opencode.json`
- `~/.config/opencode/opencode.jsonc`
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

OpenCode 的 provider、API key、本机 MCP 命令路径应放在 `~/.config/opencode/opencode.json` 或 `opencode.jsonc`，不进入 chezmoi。插件安装产生的 `~/.config/opencode/plugins/git-ai.ts` 也不进入 chezmoi。

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
- `~/.config/opencode/opencode.json`
- `~/.config/opencode/opencode.jsonc`
- `~/.config/opencode/plugins/git-ai.ts`
- 包含 `ANTHROPIC_*`、`OPENAI_*`、`CODEMAKER_*`、access token、auth key、公司 endpoint 的文件

如果误提交过 token/auth key，删除当前文件不等于清除 Git 历史，需要轮换密钥，并视情况重写远程历史。

## 新设备应用

新设备上只需要拉取并应用 chezmoi 源仓库。建议先预览再应用：

```bash
chezmoi init git@github.com:zhouatie/dotfiles.git
chezmoi diff
chezmoi apply
```

如果设备还没有 chezmoi，先安装：

```bash
brew install chezmoi
```

应用前或应用后，按需创建本机 local 配置。这些文件不会从远程同步：

```bash
touch ~/.zshrc.local.pre
touch ~/.zshrc.local
mkdir -p ~/.config/git
touch ~/.config/git/config.local
mkdir -p ~/.config/nvim/lua/plugins/local
```

`~/.gitconfig` 由 chezmoi 管理为相对软链，指向 `.config/git/config`。新设备执行 `chezmoi apply` 后不需要手动创建这个软链。

如果某台设备需要公司邮箱、credential、proxy、AI provider、MCP server、Raven/Git-AI/CodeMaker 等配置，只写入 local 文件或工具自己的本机配置，不写入本仓库。

## 修改规则

通用配置可以同步到远程，例如 shell 通用 alias、Neovim 普通插件配置、WezTerm/Yazi/tmux 通用偏好。

本机绑定内容不要同步到远程，包括：

- 绝对 HOME 路径，例如 `/Users/zhoushitie/...`
- 公司邮箱、工号、token、API key、auth key
- 公司 endpoint、内网 npm registry、代理地址
- AI 工具 hooks、session、log、monitor、trace2、checkpoint 配置
- 插件依赖目录、`node_modules`、工具生成的 receipt/cache/backup

路径写法优先使用 `$HOME`、`~`、相对软链，或工具提供的 home API。例如：

- zsh 使用 `$HOME`
- Git 使用 `~/.config/...`
- Neovim Lua 使用 `vim.fn.expand("~/...")`
- WezTerm 使用 `wezterm.home_dir`
- Yazi 配置中使用 `~`

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
