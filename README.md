## about

通过使用 `chezmoi` 维护的 `dotfiles` 文件配置，一键更新自己的配置文件

## 操作

### 克隆仓库

`git clone git@github.com:zhouatie/dotfiles.git`

### 添加

`chezmoi add ~/.zshrc`

### remove

`chezmoi forget ~/.zshrc`

### 应用

`chezmoi apply`

## 其他

其中 `proxy.pac`,`tvbox.json` 放在这里只是利用了 `github pages` 的功能，作为远程服务器，提供 `http` 访问的能力。

## 配置访问地址

如：

`https://raw.githubusercontent.com/zhouatie/dotfiles/main/proxy.pac`
