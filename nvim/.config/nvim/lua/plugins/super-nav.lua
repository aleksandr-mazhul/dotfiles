-- Ctrl+hjkl window nav (matches HRM D=Ctrl). Super reserved for clear/redraw elsewhere.
return {
  {
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, opts)
      opts = opts or {}
      opts.terminal = opts.terminal or {}
      opts.terminal.win = opts.terminal.win or {}
      local function term_nav(dir)
        return function(self)
          if self:is_floating() then
            return "<c-" .. dir .. ">"
          end
          return vim.schedule(function()
            vim.cmd.wincmd(dir)
          end)
        end
      end
      opts.terminal.win.keys = vim.tbl_extend("force", opts.terminal.win.keys or {}, {
        nav_h = { "<C-h>", term_nav("h"), desc = "Go to Left Window", expr = true, mode = "t" },
        nav_j = { "<C-j>", term_nav("j"), desc = "Go to Lower Window", expr = true, mode = "t" },
        nav_k = { "<C-k>", term_nav("k"), desc = "Go to Upper Window", expr = true, mode = "t" },
        nav_l = { "<C-l>", term_nav("l"), desc = "Go to Right Window", expr = true, mode = "t" },
      })
      return opts
    end,
  },
  {
    "christoomey/vim-tmux-navigator",
    optional = true,
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right" },
      { "<D-h>", false },
      { "<D-j>", false },
      { "<D-k>", false },
      { "<D-l>", false },
    },
  },
}
