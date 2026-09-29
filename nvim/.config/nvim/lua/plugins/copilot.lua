return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function(_, opts)
      local function start()
        require("copilot").setup(opts)
      end
      local function vpn_up()
        local out = vim.fn.system({ "windscribe-cli", "status" })
        return type(out) == "string" and out:lower():find("connect state: connected", 1, true) ~= nil
      end
      if vpn_up() then
        start()
        return
      end
      local tries = 0
      local timer = vim.uv.new_timer()
      timer:start(1000, 1000, vim.schedule_wrap(function()
        tries = tries + 1
        if vpn_up() then
          timer:stop()
          timer:close()
          start()
        elseif tries >= 300 then
          timer:stop()
          timer:close()
        end
      end))
    end,
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<Tab>",
          next = "<M-]>",
          prev = "<M-[>",
        },
      },
      panel = { enabled = false },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      {
        "zbirenbaum/copilot-cmp",
        dependencies = { "zbirenbaum/copilot.lua" },
        config = function()
          local copilot_cmp = require("copilot_cmp")
          copilot_cmp.setup()
          Snacks.util.lsp.on({ name = "copilot" }, function()
            copilot_cmp._on_insert_enter({})
          end)
        end,
      },
    },
    opts = function(_, opts)
      opts.sources = opts.sources or {}

      local has_copilot = false
      for _, source in ipairs(opts.sources) do
        if source.name == "copilot" then
          has_copilot = true
          break
        end
      end
      if not has_copilot then
        table.insert(opts.sources, 1, { name = "copilot", group_index = 1, priority = 100 })
      end

      LazyVim.cmp.actions.ai_accept = function()
        if require("copilot.suggestion").is_visible() then
          LazyVim.create_undo()
          require("copilot.suggestion").accept()
          return true
        end
      end
    end,
  },
}
