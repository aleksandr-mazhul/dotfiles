-- Window focus with Ctrl+hjkl (HRM D-finger = Ctrl on Linux).
-- Super+L = redraw screen (swapped with former Ctrl+L clear/redraw).
-- Kanata unchanged.

local function map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- Ensure LazyVim-style Ctrl window nav (override any Super leftovers)
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window", remap = true })
map("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window", remap = true })
map("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window", remap = true })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window", remap = true })

map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Super+L = redraw (was Ctrl+L); don't steal Ctrl+L from window focus
pcall(vim.keymap.del, "n", "<D-h>")
pcall(vim.keymap.del, "n", "<D-j>")
pcall(vim.keymap.del, "n", "<D-k>")
pcall(vim.keymap.del, "n", "<D-l>")
map("n", "<D-l>", "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>", {
  desc = "Redraw screen",
})

-- Super+V = visual-block (Mac Ctrl+V; Linux Ctrl+V is terminal paste)
map({ "n", "x" }, "<D-v>", "<C-v>", { desc = "Visual block", remap = true })

-- Existing custom maps
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
