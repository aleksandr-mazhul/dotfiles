return {
  {
    'Civitasv/cmake-tools.nvim',

    cmd = {
      'CMakeGenerate',
      'CMakeBuild',
      'CMakeRun',
      'CMakeDebug',
      'CMakeSelectBuildTarget',
      'CMakeSelectLaunchTarget',
    },

    dependencies = {
      'nvim-lua/plenary.nvim',
    },

    opts = {
      cmake_build_directory = 'build',

      cmake_generate_options = {
        '-G',
        'Ninja',
        '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON',
      },

      cmake_soft_link_compile_commands = true,
      cmake_compile_commands_from_lsp = true,
      cmake_notifications = true,

      cmake_runner = {
        name = 'toggleterm',

        default_opts = {
          toggleterm = {
            direction = 'horizontal',
            close_on_exit = false,
            auto_scroll = true,
          },
        },
      },
    },

    keys = {
      {
        '<leader>ms',
        function()
          require('cmake-tools').select_launch_target()
        end,
        desc = 'Select Launch Target',
      },

      {
        '<leader>rb',
        '<cmd>CMakeBuild<cr>',
        desc = 'Build',
      },

      {
        '<leader>rr',
        '<cmd>CMakeRun<cr>',
        desc = 'Run',
      },

      {
        '<leader>rd',
        '<cmd>CMakeDebug<cr>',
        desc = 'Debug',
      },

      {
        '<leader>mc',
        function()
          vim.fn.jobstart('cmake-sync', {
            stdout_buffered = true,
            stderr_buffered = true,

            on_stdout = function(_, data)
              if not data then
                return
              end

              local msg = table.concat(data, '\n'):gsub('\n+$', '')

              if msg ~= '' then
                vim.schedule(function()
                  vim.notify(msg, vim.log.levels.INFO, {
                    title = 'CMake',
                  })
                end)
              end
            end,

            on_stderr = function(_, data)
              if not data then
                return
              end

              local msg = table.concat(data, '\n'):gsub('\n+$', '')

              if msg ~= '' then
                vim.schedule(function()
                  vim.notify(msg, vim.log.levels.ERROR, {
                    title = 'CMake',
                  })
                end)
              end
            end,
          })
        end,

        desc = 'Sync CMake',
      },
    },
  },
}
