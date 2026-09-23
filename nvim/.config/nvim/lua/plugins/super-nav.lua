-- Super+hjkl window nav: kitty sends them as <M-hjkl> through tmux (see keymaps.lua).
-- Super+H/L are also code↔tree when nvim runs directly in kitty.
local NAV_CMD = { h = "TmuxNavigateLeft", j = "TmuxNavigateDown", k = "TmuxNavigateUp", l = "TmuxNavigateRight" }

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
            return "<m-" .. dir .. ">"
          end
          return vim.schedule(function()
            vim.cmd(NAV_CMD[dir])
          end)
        end
      end
      opts.terminal.win.keys = vim.tbl_extend("force", opts.terminal.win.keys or {}, {
        nav_h = { "<M-h>", term_nav("h"), desc = "Go to Left Window", expr = true, mode = "t" },
        nav_j = { "<M-j>", term_nav("j"), desc = "Go to Lower Window", expr = true, mode = "t" },
        nav_k = { "<M-k>", term_nav("k"), desc = "Go to Upper Window", expr = true, mode = "t" },
        nav_l = { "<M-l>", term_nav("l"), desc = "Go to Right Window", expr = true, mode = "t" },
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
      -- The tree is a float, so plain window moves get stuck in nvim.
      -- Route Super+hjkl through TreeEscape (keymaps.lua).
      local function nav(dir)
        return function()
          _G.TreeEscape(dir)
        end
      end
      opts.picker.sources.explorer = vim.tbl_deep_extend("force", opts.picker.sources.explorer or {}, {
        win = {
          list = {
            keys = {
              ["<D-l>"] = back_to_code,
              ["<F14>"] = back_to_code,
              ["<D-h>"] = "focus_list",
              ["<F13>"] = "focus_list",
              ["<m-h>"] = nav("h"),
              ["<m-j>"] = nav("j"),
              ["<m-k>"] = nav("k"),
              ["<m-l>"] = nav("l"),
            },
          },
          input = {
            keys = {
              ["<m-h>"] = { nav("h"), mode = { "i", "n" } },
              ["<m-j>"] = { nav("j"), mode = { "i", "n" } },
              ["<m-k>"] = { nav("k"), mode = { "i", "n" } },
              ["<m-l>"] = { nav("l"), mode = { "i", "n" } },
            },
          },
        },
      })
      return opts
    end,
  },
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    init = function()
      -- Keys live in keymaps.lua; stop the plugin from grabbing Ctrl+hjkl.
      vim.g.tmux_navigator_no_mappings = 1
    end,
    keys = {
      { "<D-h>", false },
      { "<D-j>", false },
      { "<D-k>", false },
      { "<D-l>", false },
    },
  },
}
