# NeoVim Configuration

My personal NeoVim configuration based on LazyVim

## Setup Instructions

1. Clone this repository to `~/.config/nvim`

```bash
git clone https://github.com/yourusername/nvim-config.git ~/.config/nvim
```

2. Install Python support for Neovim (required for some plugins)

```bash
# Create a virtual environment for Neovim
python3 -m venv ~/.config/nvim/venv

# Install pynvim in the virtual environment
~/.config/nvim/venv/bin/pip install pynvim
```

3. Install other dependencies

```bash
# For macOS
brew install wget ripgrep fd lazygit fzf

# For Ubuntu/Debian
sudo apt install wget ripgrep fd-find lazygit fzf
```

## Features

- Modern UI with Catppuccin theme
- LSP support for multiple languages
- Debugging with DAP
- Fuzzy finding with Telescope
- AI coding assistance with Copilot
- Git integration with Gitsigns and Lazygit
- Enhanced markdown with Obsidian integration
- And more!

## Key Plugins

- [LazyVim](https://github.com/LazyVim/LazyVim) - Neovim config for the lazy
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Plugin manager
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) - Syntax highlighting
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Fuzzy finder
- [mason.nvim](https://github.com/williamboman/mason.nvim) - Package manager
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) - LSP configuration
- [copilot.lua](https://github.com/zbirenbaum/copilot.lua) - GitHub Copilot integration
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) - Debug adapter protocol
