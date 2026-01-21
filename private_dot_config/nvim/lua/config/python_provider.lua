-- Python provider 配置
vim.g.python3_host_prog = vim.fn.expand("~/.config/nvim/venv/bin/python3")

-- 不需要的 Provider 可以禁用
vim.g.loaded_ruby_provider = 0  -- 禁用 Ruby provider
vim.g.loaded_perl_provider = 0  -- 禁用 Perl provider
