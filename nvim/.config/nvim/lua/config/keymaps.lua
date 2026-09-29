-- Ctrl+hjkl = window focus.
-- Super+H/L = code ↔ file tree (via <D-h>/<D-l> and F13/F14 from kitty).

local function map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

local function is_tree_buf(buf)
  buf = buf or 0
  local ft = vim.bo[buf].filetype
  return ft == "snacks_picker_list"
    or ft == "snacks_picker_input"
    or ft == "neo-tree"
    or ft == "NvimTree"
    or ft == "oil"
end

local function focus_tree()
  local ok, Snacks = pcall(require, "snacks")
  if ok and Snacks.picker then
    local explorers = Snacks.picker.get({ source = "explorer" })
    if explorers[1] then
      explorers[1]:focus("list", { show = true })
      return
    end
    if Snacks.explorer then
      Snacks.explorer({ cwd = (LazyVim and LazyVim.root and LazyVim.root()) or nil })
      return
    end
  end

  if vim.fn.exists(":Neotree") == 2 then
    vim.cmd("Neotree reveal focus")
    return
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_tree_buf(vim.api.nvim_win_get_buf(win)) then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  vim.notify("File tree not available (open with <leader>e)", vim.log.levels.WARN)
end

local function focus_code()
  local cur = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= cur and not is_tree_buf(vim.api.nvim_win_get_buf(win)) then
      local cfg = vim.api.nvim_win_get_config(win)
      if cfg.relative == "" then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end
  vim.cmd.wincmd("p")
end

-- The snacks explorer is a float over a "layout box" split, so `wincmd h/j/k` from
-- the tree lands in the code window. Step from the box instead; at the edge, leave
-- to tmux/zellij.
local TMUX_DIR = { h = "L", j = "D", k = "U", l = "R" }
local NAV_CMD = { h = "TmuxNavigateLeft", j = "TmuxNavigateDown", k = "TmuxNavigateUp", l = "TmuxNavigateRight" }
local ZELLIJ_DIR = { h = "left", j = "down", k = "up", l = "right" }

-- Async, fire-and-forget zellij focus move. Shared by mux_nav below and by
-- tree_escape's own edge-of-explorer branch, which must dispatch directly
-- (not through mux_nav's wincmd step) since the current window there is the
-- tree float itself, and wincmd from the float lands in the code window
-- (see comment above) rather than leaving nvim.
local function zellij_move_focus(dir)
  vim.fn.jobstart({ "zellij", "action", "move-focus", ZELLIJ_DIR[dir] }, { detach = true })
end

-- Move to the nvim window in `dir` (hjkl); if the window didn't change, hand
-- off to the multiplexer: zellij (`$ZELLIJ` set) gets an async move-focus
-- action, tmux (or nothing) keeps using vim-tmux-navigator's TmuxNavigate*
-- exactly as before.
local function mux_nav(dir)
  local cur = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. dir)
  if vim.api.nvim_get_current_win() ~= cur then
    return
  end
  if vim.env.ZELLIJ then
    zellij_move_focus(dir)
  else
    vim.cmd(NAV_CMD[dir])
  end
end

local function tree_escape(dir)
  vim.cmd("stopinsert")
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_layout_box" then
      local next = vim.api.nvim_win_call(win, function()
        return vim.fn.win_getid(vim.fn.winnr(dir))
      end)
      if next ~= win then
        vim.api.nvim_set_current_win(next)
      elseif vim.env.ZELLIJ then
        zellij_move_focus(dir)
      elseif vim.env.TMUX then
        vim.fn.system({ "tmux", "select-pane", "-" .. TMUX_DIR[dir] })
      end
      return
    end
  end
  vim.cmd(NAV_CMD[dir])
end

-- expose for :lua and tests
_G.FocusFileTree = focus_tree
_G.FocusCodeWindow = focus_code
_G.TreeEscape = tree_escape
_G.MuxNav = mux_nav

-- Super+hjkl arrive as <M-hjkl> (kitty → tmux/zellij): move between splits,
-- and past the edge into the next tmux pane or zellij pane (mux_nav above).
-- Overrides LazyVim's Alt+j/k line moves. Ctrl+hjkl go back to plain Vim keys.
for _, lhs in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
  pcall(vim.keymap.del, "n", lhs)
end
map({ "n", "i", "v" }, "<M-h>", function() mux_nav("h") end, { desc = "Go to Left Window / tmux/zellij pane" })
map({ "n", "i", "v" }, "<M-j>", function() mux_nav("j") end, { desc = "Go to Lower Window / tmux/zellij pane" })
map({ "n", "i", "v" }, "<M-k>", function() mux_nav("k") end, { desc = "Go to Upper Window / tmux/zellij pane" })
map({ "n", "i", "v" }, "<M-l>", function() mux_nav("l") end, { desc = "Go to Right Window / tmux/zellij pane" })

map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Super+H/L: D- (GUI / kitty protocol) + F13/F14 (kitty send_key bridge on Linux)
-- Chain into tmux/zellij pane navigation once there is nothing left to move to inside Neovim.
for _, lhs in ipairs({ "<D-h>", "<F13>" }) do
  map({ "n", "i", "v", "t" }, lhs, function()
    vim.cmd("stopinsert")
    if is_tree_buf(vim.api.nvim_get_current_buf()) then
      tree_escape("h")
    else
      focus_tree()
    end
  end, { desc = "Focus file tree, or escape left to tmux/zellij" })
end
for _, lhs in ipairs({ "<D-l>", "<F14>" }) do
  map({ "n", "i", "v", "t" }, lhs, function()
    vim.cmd("stopinsert")
    if is_tree_buf(vim.api.nvim_get_current_buf()) then
      focus_code()
    else
      mux_nav("l")
    end
  end, { desc = "Focus code, or escape right to tmux/zellij" })
end

map({ "n", "x" }, "<D-v>", "<C-v>", { desc = "Visual block", remap = true })

map("n", "<leader>gg", function()
  local Terminal = require("toggleterm.terminal").Terminal
  local lazygit = Terminal:new({
    cmd = "lazygit",
    dir = "git_dir",
    hidden = true,
    direction = "float",
  })
  lazygit:toggle()
end, { desc = "Lazygit" })

map("n", "<leader>bd", function()
  Snacks.bufdelete()
end, { desc = "Delete Buffer" })

map("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close Tab" })

-- :substitute in this file. <leader>sr stays grug-far (project).
-- Visual mode is already over when a Lua mapping runs, so the two modes
-- pass the origin explicitly instead of checking mode().
map("n", "<leader>sF", function()
  require("config.substitute").start(false)
end, { desc = "Substitute in file" })
map("x", "<leader>sF", function()
  require("config.substitute").start(true)
end, { desc = "Substitute in file" })
