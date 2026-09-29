-- SSOT theme bridge for LazyVim / tokyonight
return {
  {
    "folke/tokyonight.nvim",
    optional = true,
    opts = function(_, opts)
      opts = opts or {}
      local ok, pal = pcall(require, "config.palette")
      if not ok or type(pal) ~= "table" then
        return opts
      end
      opts.style = opts.style or "night"
      opts.on_colors = function(colors)
        -- Refresh the upvalue so a palette.lua rewrite is visible when
        -- :colorscheme runs again after a wallpaper change.
        local fresh_ok, fresh = pcall(require, "config.palette")
        if fresh_ok and type(fresh) == "table" then
          pal = fresh
        end
        local hi = pal.surface_container_high or pal.surface_container
        colors.bg = pal.background
        colors.bg_dark = pal.background
        colors.bg_dark1 = pal.background
        colors.bg_float = pal.surface_container
        colors.bg_highlight = hi
        colors.bg_popup = pal.surface_container
        colors.bg_search = pal.primary_container
        colors.bg_sidebar = pal.surface
        colors.bg_statusline = pal.surface_container
        colors.bg_visual = pal.primary_container
        colors.border = pal.outline
        colors.fg = pal.on_surface
        colors.fg_dark = pal.on_surface_variant
        colors.fg_float = pal.on_surface
        colors.fg_gutter = pal.surface_variant
        colors.fg_sidebar = pal.on_surface
        colors.comment = pal.on_surface_variant
        colors.blue = pal.primary
        colors.blue0 = pal.primary_container
        colors.blue1 = pal.primary
        colors.blue2 = pal.secondary
        colors.blue5 = pal.secondary
        colors.blue6 = pal.tertiary
        colors.blue7 = pal.primary_container
        colors.cyan = pal.secondary
        colors.green = pal.tertiary
        colors.green1 = pal.tertiary
        colors.green2 = pal.tertiary
        colors.magenta = pal.secondary
        colors.magenta2 = pal.primary
        colors.orange = pal.primary
        colors.purple = pal.secondary
        colors.red = pal.error
        colors.red1 = pal.error
        colors.teal = pal.secondary
        colors.yellow = pal.tertiary
        colors.dark3 = pal.surface_variant
        colors.dark5 = pal.surface_variant
        colors.terminal_black = pal.surface
        colors.black = pal.background
        -- These are copied from the stock palette BEFORE this hook, so
        -- floats, which-key frames and the info "Saved" toast stay Tokyo
        -- Night cyan unless they are overwritten here.
        colors.border_highlight = pal.outline
        colors.info = pal.secondary
        colors.hint = pal.tertiary
        colors.warning = pal.primary
        colors.error = pal.error
        colors.todo = pal.primary
        colors.diff = {
          add = hi,
          delete = pal.primary_container,
          change = pal.surface_container,
          text = pal.primary,
        }
        if type(colors.git) == "table" then
          colors.git.add = pal.tertiary
          colors.git.change = pal.primary
          colors.git.delete = pal.error
          colors.git.ignore = pal.surface_variant
        end
        if type(colors.terminal) == "table" then
          colors.terminal.black = pal.background
          colors.terminal.black_bright = pal.surface_variant
          colors.terminal.red = pal.error
          colors.terminal.red_bright = pal.error
          colors.terminal.green = pal.tertiary
          colors.terminal.green_bright = pal.tertiary
          colors.terminal.yellow = pal.tertiary
          colors.terminal.yellow_bright = pal.tertiary
          colors.terminal.blue = pal.primary
          colors.terminal.blue_bright = pal.primary
          colors.terminal.magenta = pal.secondary
          colors.terminal.magenta_bright = pal.secondary
          colors.terminal.cyan = pal.secondary
          colors.terminal.cyan_bright = pal.secondary
          colors.terminal.white = pal.on_surface_variant
          colors.terminal.white_bright = pal.on_surface
        end
      end
      return opts
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
