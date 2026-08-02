-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Linux: system Python (Mac used Homebrew python@3.13)
vim.g.python3_host_prog = vim.fn.exepath('python3')

-- Wayland clipboard via wl-clipboard (nvim auto-detects wl-copy/wl-paste)
vim.opt.clipboard = 'unnamedplus'
