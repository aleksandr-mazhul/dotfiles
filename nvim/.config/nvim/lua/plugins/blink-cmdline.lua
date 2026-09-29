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
    completion = {
      -- LSP / buffer / path suggestions stay in the menu under the cursor.
      -- Inline ghost text is Copilot's only, so the two previews don't stack.
      ghost_text = { enabled = false },
    },
    cmdline = {
      keymap = {
        ["<Up>"] = { menu_or_history("select_prev"), "fallback" },
        ["<Down>"] = { menu_or_history("select_next"), "fallback" },
      },
    },
  },
}
