return {
  {
    'Weissle/persistent-breakpoints.nvim',
    event = 'BufReadPost',
    config = function()
      require('persistent-breakpoints').setup({
        load_breakpoints_event = { 'BufReadPost' },
      })
    end,
  },
}
