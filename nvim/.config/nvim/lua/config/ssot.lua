-- Apply SSOT palette highlights + watch palette.lua for live theme updates
local M = {}

function M.apply()
  local ok, pal = pcall(require, "config.palette")
  if not ok or type(pal) ~= "table" then
    return
  end
  local function hl(group, spec)
    vim.api.nvim_set_hl(0, group, spec)
  end
  hl("@keyword", { fg = pal.primary, bold = true })
  hl("@string", { fg = pal.secondary })
  hl("@function", { fg = pal.tertiary })
  hl("@function.builtin", { fg = pal.tertiary })
  hl("@type", { fg = pal.tertiary })
  hl("@constant", { fg = pal.outline })
  hl("@comment", { fg = pal.on_surface_variant, italic = true })
  hl("@variable", { fg = pal.on_surface })
  hl("DiagnosticError", { fg = pal.error })
  hl("DiagnosticWarn", { fg = pal.primary })
  hl("DiagnosticInfo", { fg = pal.secondary })
  hl("DiagnosticHint", { fg = pal.outline })
  hl("CursorLine", { bg = pal.surface_container })
  hl("Visual", { bg = pal.primary_container })
  hl("LineNr", { fg = pal.surface_variant })
  hl("CursorLineNr", { fg = pal.primary, bold = true })
  hl("VertSplit", { fg = pal.outline })
  hl("WinSeparator", { fg = pal.outline })
  hl("StatusLine", { fg = pal.on_surface, bg = pal.surface_container })
  hl("Pmenu", { fg = pal.on_surface, bg = pal.surface_container })
  hl("PmenuSel", { fg = pal.on_primary, bg = pal.primary })
  hl("TelescopeSelection", { fg = pal.on_primary, bg = pal.primary })
  hl("TelescopeBorder", { fg = pal.outline })
end

function M.setup()
  M.apply()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("SsotTheme", { clear = true }),
    callback = function()
      M.apply()
    end,
  })
  local palette_path = vim.fn.stdpath("config") .. "/lua/config/palette.lua"
  local ok_w, watcher = pcall(vim.uv.new_fs_event)
  if ok_w and watcher then
    watcher:start(
      palette_path,
      {},
      vim.schedule_wrap(function()
        package.loaded["config.palette"] = nil
        M.apply()
      end)
    )
  end
end

return M
