return {
  {
    'LazyVim/LazyVim',
    opts = function()
      local group = vim.api.nvim_create_augroup('AutoSave', { clear = true })

      vim.api.nvim_create_autocmd({ 'FocusLost', 'BufLeave', 'InsertLeave' }, {
        group = group,
        callback = function(args)
          local buf = args.buf

          if not vim.api.nvim_buf_is_valid(buf) then
            return
          end
          if not vim.bo[buf].modified then
            return
          end
          if vim.bo[buf].buftype ~= '' then
            return
          end
          if not vim.bo[buf].modifiable or vim.bo[buf].readonly then
            return
          end

          vim.cmd('silent write')

          vim.schedule(function()
            vim.notify('󰄳 Saved', vim.log.levels.INFO, {
              title = 'AutoSave',
              timeout = 500,
            })
          end)
        end,
      })
    end,
  },
}
