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

-- expose for :lua and tests
_G.FocusFileTree = focus_tree
_G.FocusCodeWindow = focus_code

map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window", remap = true })
map("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window", remap = true })
map("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window", remap = true })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window", remap = true })

map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Super+H/L: D- (GUI / kitty protocol) + F13/F14 (kitty send_key bridge on Linux)
for _, lhs in ipairs({ "<D-h>", "<F13>" }) do
  map({ "n", "i", "v", "t" }, lhs, function()
    vim.cmd("stopinsert")
    focus_tree()
  end, { desc = "Focus file tree" })
end
for _, lhs in ipairs({ "<D-l>", "<F14>" }) do
  map({ "n", "i", "v", "t" }, lhs, function()
    vim.cmd("stopinsert")
    focus_code()
  end, { desc = "Focus code" })
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
