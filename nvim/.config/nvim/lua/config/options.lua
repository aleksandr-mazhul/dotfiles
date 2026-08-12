-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Linux: system Python (Mac used Homebrew python@3.13)
vim.g.python3_host_prog = vim.fn.exepath('python3')

-- Shared system ↔ Neovim clipboard (Hyprland / wl-clipboard).
-- unnamedplus: yank/delete/put use "+" (= Ctrl+C / Ctrl+V / cliphist).
vim.opt.clipboard = "unnamedplus"

local function has(bin)
  return vim.fn.executable(bin) == 1
end

if has("wl-copy") and has("wl-paste") then
  vim.g.clipboard = {
    name = "wl-clipboard",
    copy = {
      ["+"] = { "wl-copy", "--type", "text/plain" },
      ["*"] = { "wl-copy", "--type", "text/plain", "--primary" },
    },
    paste = {
      ["+"] = { "wl-paste", "--no-newline", "--type", "text/plain" },
      ["*"] = { "wl-paste", "--no-newline", "--type", "text/plain", "--primary" },
    },
    cache_enabled = 1,
  }
elseif vim.fn.has("nvim-0.10") == 1 then
  -- SSH / no Wayland: still push yanks to the outer terminal clipboard
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
  }
end

-- Spelling off by default (LazyVim turns it on for markdown — noisy for notes/homework).
-- Russian dict is available if you enable: <leader>us  (spelllang=en,ru)
vim.opt.spell = false
vim.opt.spelllang = { "en", "ru" }

-- LazyVim defaults conceallevel=2 → markdown [text](url) hides the URL off-cursor.
-- Keep markup visible (links, bold markers, etc.). Toggle: <leader>uc
vim.opt.conceallevel = 0
