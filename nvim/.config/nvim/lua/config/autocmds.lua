-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- SSOT palette → syntax / UI highlights (live-reloads on palette.lua change)
pcall(function()
  require("config.ssot").setup()
end)

-- LazyVim enables spell in markdown/text (spelllang often incomplete → red underlines
-- on Russian + tech terms like GitLab). Turn that off; toggle manually with <leader>us.
pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "gitcommit", "text" },
  callback = function()
    vim.opt_local.spell = false
    -- Keep markdown links/URLs visible (LazyVim default conceallevel=2 hides them)
    vim.opt_local.conceallevel = 0
    vim.opt_local.concealcursor = ""
  end,
})
