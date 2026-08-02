return {
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    opts = {
      direction = 'horizontal',
      size = 15,
      close_on_exit = false,
      shade_terminals = false,
      start_in_insert = true,
      insert_mappings = true,
      auto_scroll = true,
      shell = vim.o.shell,
    },
    keys = {
      {
        '<leader>tt',
        '<cmd>ToggleTerm<cr>',
        desc = 'Terminal',
      },
    },
  },
}
