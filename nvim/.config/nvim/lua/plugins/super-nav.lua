-- Ctrl+hjkl window nav. Super+H/L are code↔tree in keymaps.lua.
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

      -- From inside explorer: Super+L / F14 → back to code
      local function back_to_code()
        if _G.FocusCodeWindow then
          _G.FocusCodeWindow()
          return
        end
        vim.cmd.wincmd("l")
      end
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.explorer = vim.tbl_deep_extend("force", opts.picker.sources.explorer or {}, {
        win = {
          list = {
            keys = {
              ["<D-l>"] = back_to_code,
              ["<F14>"] = back_to_code,
              ["<D-h>"] = "focus_list",
              ["<F13>"] = "focus_list",
            },
          },
        },
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
