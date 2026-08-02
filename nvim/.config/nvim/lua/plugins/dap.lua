return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui',
      'theHamsta/nvim-dap-virtual-text',
      'leoluz/nvim-dap-go',
      'mxsdev/nvim-dap-vscode-js',
      'nvim-neotest/nvim-nio',
      'Weissle/persistent-breakpoints.nvim',
    },

    keys = {
      -- execution
      {
        '<leader>dc',
        function()
          require('dap').continue()
        end,
        desc = 'Debug Continue',
      },
      {
        '<leader>dh',
        function()
          require('dap').pause()
        end,
        desc = 'Debug Pause',
      },
      {
        '<leader>dr',
        function()
          require('dap').restart()
        end,
        desc = 'Debug Restart',
      },
      {
        '<leader>dq',
        function()
          require('dap').terminate()
        end,
        desc = 'Debug Quit',
      },

      -- stepping
      {
        '<leader>dj',
        function()
          require('dap').step_over()
        end,
        desc = 'Debug Step Over',
      },
      {
        '<leader>dk',
        function()
          require('dap').step_into()
        end,
        desc = 'Debug Step Into',
      },
      {
        '<leader>dl',
        function()
          require('dap').step_out()
        end,
        desc = 'Debug Step Out',
      },
      {
        '<leader>do',
        function()
          require('dap').run_to_cursor()
        end,
        desc = 'Debug Run To Cursor',
      },

      -- breakpoints
      {
        '<leader>db',
        function()
          require('persistent-breakpoints.api').toggle_breakpoint()
        end,
        desc = 'Debug Breakpoint',
      },
      {
        '<leader>dB',
        function()
          require('dap').set_breakpoint(vim.fn.input('Condition: '))
        end,
        desc = 'Debug Conditional Breakpoint',
      },
      {
        '<leader>dm',
        function()
          require('dap').set_breakpoint(nil, nil, vim.fn.input('Log message: '))
        end,
        desc = 'Debug Log Point',
      },
      {
        '<leader>dx',
        function()
          require('persistent-breakpoints.api').clear_all_breakpoints()
        end,
        desc = 'Debug Clear Breakpoints',
      },
      -- inspect
      {
        '<leader>de',
        function()
          require('dapui').eval()
        end,
        mode = { 'n', 'v' },
        desc = 'Debug Eval',
      },
      {
        '<leader>dw',
        function()
          require('dapui').elements.watches.add(vim.fn.input('Watch: '))
        end,
        desc = 'Debug Watch',
      },
      {
        '<leader>di',
        function()
          require('dap').repl.open()
        end,
        desc = 'Debug REPL',
      },
      {
        '<leader>df',
        function()
          require('dapui').float_element()
        end,
        desc = 'Debug Float',
      },

      -- ui
      {
        '<leader>du',
        function()
          require('dapui').toggle()
        end,
        desc = 'Debug UI',
      },

      -- advanced
      {
        '<leader>da',
        function()
          require('dap').continue({ before = require('dap.utils').pick_process })
        end,
        desc = 'Debug Attach',
      },
      {
        '<leader>d1',
        function()
          require('dap').set_breakpoint(nil, nil, nil, true)
        end,
        desc = 'Debug Temp Breakpoint',
      },
    },

    config = function()
      local dap = require('dap')
      local dapui = require('dapui')

      dapui.setup()
      require('nvim-dap-virtual-text').setup()

      -- Go
      require('dap-go').setup()

      -- JS / TS
      require('dap-vscode-js').setup({
        debugger_path = vim.fn.stdpath('data') .. '/mason/packages/js-debug-adapter',
        adapters = {
          'pwa-node',
          'pwa-chrome',
          'node-terminal',
          'pwa-extensionHost',
        },
      })

      for _, language in ipairs({
        'javascript',
        'typescript',
      }) do
        dap.configurations[language] = {
          {
            type = 'pwa-node',
            request = 'launch',
            name = 'Launch current file',
            program = '${file}',
            cwd = '${workspaceFolder}',
            sourceMaps = true,
          },
          {
            type = 'pwa-node',
            request = 'attach',
            name = 'Attach to process',
            processId = require('dap.utils').pick_process,
            cwd = '${workspaceFolder}',
          },
          {
            type = 'pwa-chrome',
            request = 'launch',
            name = 'Launch Chrome (:3000)',
            url = 'http://localhost:3000',
            webRoot = '${workspaceFolder}',
          },
        }
      end

      dap.configurations.javascriptreact = dap.configurations.javascript
      dap.configurations.typescriptreact = dap.configurations.typescript

      -- C / C++
      dap.adapters.codelldb = {
        type = 'server',
        port = '${port}',
        executable = {
          command = vim.fn.stdpath('data') .. '/mason/packages/codelldb/extension/adapter/codelldb',
          args = { '--port', '${port}' },
        },
      }

      dap.configurations.cpp = {
        {
          name = 'Launch file',
          type = 'codelldb',
          request = 'launch',
          program = function()
            return vim.fn.input('Executable path: ', vim.fn.getcwd() .. '/', 'file')
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
        },
      }

      dap.configurations.c = dap.configurations.cpp

      -- ui lifecycle
      dap.listeners.after.event_initialized['dapui_config'] = function()
        dapui.open()
      end

      dap.listeners.before.event_terminated['dapui_config'] = function()
        dapui.close()
      end

      dap.listeners.before.event_exited['dapui_config'] = function()
        dapui.close()
      end

      -- signs
      vim.fn.sign_define('DapBreakpoint', {
        text = '🔴',
        texthl = 'DiagnosticError',
      })

      vim.fn.sign_define('DapStopped', {
        text = '▶',
        texthl = 'DiagnosticWarn',
      })
    end,
  },
}
