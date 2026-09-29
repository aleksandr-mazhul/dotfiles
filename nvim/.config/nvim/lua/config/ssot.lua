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
  hl("TelescopeBorder", { fg = pal.outline, bg = pal.surface_container })

  -- Floating chrome. which-key's side menu (operator "Change", leader
  -- groups) draws WhichKeyBorder, and noice/snacks "Saved" toasts draw
  -- SnacksNotifier* — both otherwise keep Tokyo Night cyan.
  local float_bg = pal.surface_container
  hl("NormalFloat", { fg = pal.on_surface, bg = float_bg })
  hl("FloatBorder", { fg = pal.outline, bg = float_bg })
  hl("FloatTitle", { fg = pal.primary, bg = float_bg })
  hl("WhichKey", { fg = pal.primary })
  hl("WhichKeyGroup", { fg = pal.secondary })
  hl("WhichKeyDesc", { fg = pal.on_surface })
  hl("WhichKeySeparator", { fg = pal.outline })
  hl("WhichKeyValue", { fg = pal.on_surface_variant })
  hl("WhichKeyNormal", { fg = pal.on_surface, bg = float_bg })
  hl("WhichKeyBorder", { fg = pal.outline, bg = float_bg })
  hl("WhichKeyTitle", { fg = pal.primary, bg = float_bg })

  local icon_fg = {
    Grey = pal.on_surface_variant,
    Purple = pal.secondary,
    Blue = pal.primary,
    Azure = pal.secondary,
    Cyan = pal.secondary,
    Green = pal.tertiary,
    Yellow = pal.tertiary,
    Orange = pal.primary,
    Red = pal.error,
  }
  for name, fg in pairs(icon_fg) do
    hl("MiniIcons" .. name, { fg = fg })
    hl("WhichKeyIcon" .. name, { fg = fg })
  end
  hl("WhichKeyIcon", { fg = pal.primary })

  local function notifier(level, accent)
    hl("SnacksNotifier" .. level, { fg = pal.on_surface, bg = float_bg })
    hl("SnacksNotifierBorder" .. level, { fg = accent, bg = float_bg })
    hl("SnacksNotifierIcon" .. level, { fg = accent })
    hl("SnacksNotifierTitle" .. level, { fg = accent })
    hl("SnacksNotifierFooter" .. level, { fg = accent })
  end
  notifier("Info", pal.secondary)
  notifier("Warn", pal.primary)
  notifier("Error", pal.error)
  notifier("Debug", pal.on_surface_variant)
  notifier("Trace", pal.tertiary)

  -- noice confirm / cmdline / mini views link at these.
  hl("DiagnosticVirtualTextInfo", { fg = pal.secondary, bg = float_bg })
  hl("DiagnosticVirtualTextWarn", { fg = pal.primary, bg = float_bg })
  hl("DiagnosticVirtualTextError", { fg = pal.error, bg = float_bg })
  hl("DiagnosticVirtualTextHint", { fg = pal.tertiary, bg = float_bg })
  hl("DiagnosticSignInfo", { fg = pal.secondary })
  hl("DiagnosticSignWarn", { fg = pal.primary })
  hl("DiagnosticSignError", { fg = pal.error })
  hl("DiagnosticSignHint", { fg = pal.tertiary })
  hl("DiagnosticSignOk", { fg = pal.tertiary })

  -- copilot.lua links these to Comment, which is the muted gray and
  -- disappears on the cursor line. Primary is the accent every harmony
  -- already contrasts against the background.
  hl("CopilotSuggestion", { fg = pal.primary, italic = true })
  hl("CopilotAnnotation", { fg = pal.secondary, italic = true })
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
        local name = vim.g.colors_name
        if type(name) == "string" and name ~= "" then
          -- Rebuild every tokyonight group from the new palette, then
          -- ColorScheme runs M.apply() for the float/which-key/toast groups.
          pcall(vim.cmd.colorscheme, name)
        else
          M.apply()
        end
      end)
    )
  end
end

return M
