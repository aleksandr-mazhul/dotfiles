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
        colors.bg = pal.background
        colors.bg_dark = pal.background
        colors.bg_float = pal.surface_container
        colors.bg_highlight = pal.surface_container_high or pal.surface_container
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
        colors.blue1 = pal.primary
        colors.cyan = pal.secondary
        colors.green = pal.tertiary
        colors.green1 = pal.tertiary
        colors.magenta = pal.secondary
        colors.orange = pal.primary
        colors.purple = pal.secondary
        colors.red = pal.error
        colors.red1 = pal.error
        colors.teal = pal.secondary
        colors.yellow = pal.tertiary
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
