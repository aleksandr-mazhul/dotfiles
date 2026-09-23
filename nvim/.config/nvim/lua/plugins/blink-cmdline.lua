-- Up/Down move through the cmdline completion menu once something is typed; on an
-- empty line they keep recalling history. Otherwise the arrows pull old commands in.
local function menu_or_history(select)
  return function(cmp)
    if vim.fn.getcmdline() == "" then
      return false
    end
    return cmp[select]()
  end
end

return {
  "saghen/blink.cmp",
  optional = true,
  opts = {
    cmdline = {
      keymap = {
        ["<Up>"] = { menu_or_history("select_prev"), "fallback" },
        ["<Down>"] = { menu_or_history("select_next"), "fallback" },
      },
    },
  },
}
