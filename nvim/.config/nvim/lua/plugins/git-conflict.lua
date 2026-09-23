return {
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    -- keys alone made it key-lazy: no conflict highlights or co/ct until a
    -- <leader>gc* press. Load with the first real buffer instead.
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      default_mappings = true, -- co/ct/cb/c0, ]x/[x
      default_commands = true,
      disable_diagnostics = true,
      highlights = {
        incoming = 'DiffAdd',
        current = 'DiffText',
      },
    },
    keys = {
      { '<leader>gco', '<cmd>GitConflictChooseOurs<cr>', desc = 'Conflict: ours' },
      { '<leader>gct', '<cmd>GitConflictChooseTheirs<cr>', desc = 'Conflict: theirs' },
      { '<leader>gcb', '<cmd>GitConflictChooseBoth<cr>', desc = 'Conflict: both' },
      { '<leader>gc0', '<cmd>GitConflictChooseNone<cr>', desc = 'Conflict: none' },
      { '<leader>gcn', '<cmd>GitConflictNextConflict<cr>', desc = 'Conflict: next' },
      { '<leader>gcp', '<cmd>GitConflictPrevConflict<cr>', desc = 'Conflict: prev' },
      { '<leader>gcl', '<cmd>GitConflictListQf<cr>', desc = 'Conflict: list' },
    },
  },
}
