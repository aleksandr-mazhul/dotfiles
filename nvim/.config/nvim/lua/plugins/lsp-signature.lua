return {
  {
    'ray-x/lsp_signature.nvim',
    event = 'VeryLazy',
    opts = {
      bind = true,
      hint_enable = false,
      floating_window = true,
      floating_window_above_cur_line = true,
      handler_opts = {
        border = 'rounded',
      },
      max_height = 12,
      max_width = 80,
      toggle_key = '<M-s>',
    },
    config = function(_, opts)
      require('lsp_signature').setup(opts)
    end,
  },
}
