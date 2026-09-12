
local sql_ft = { "sql", "mysql", "plsql" }

-- disable nvim default `sql_completion` plugin to be compatible with blink.cmp's omni
-- while still showing some keywords from the syntax autocomplete sources
vim.g.omni_sql_default_compl_type = "syntax"
vim.g.loaded_sql_completion = true

return {

  {
    "tpope/vim-dadbod",
    cmd = "DB",
  },

  {
    "kristijanhusak/vim-dadbod-completion",
    dependencies = "vim-dadbod",
    ft = sql_ft,
    init = function()
      -- NOTE: 插件自带的 after/plugin 会 require("completion")（老引擎 completion-nvim 的接口）并调用
      -- completion.addCompletionSource(...)。某些会话里存在同名但残缺的模块，于是进插入模式就报
      -- "attempt to call field 'addCompletionSource' (a nil value)"（本机出现过一次，之后又消失，无法复现）。
      -- 我们用的是 blink（见本文件底部 providers.dadbod = vim_dadbod_completion.blink），这条老分支无用，
      -- 所以放个空的 preload 兜底：模块缺失或残缺都不再报错，也不影响 blink 的 dadbod 源。
      local ok, mod = pcall(require, "completion")
      if not ok or type(mod) ~= "table" or type(mod.addCompletionSource) ~= "function" then
        package.preload["completion"] = function()
          return { addCompletionSource = function() end }
        end
      end
    end,
  },

  {
    "kristijanhusak/vim-dadbod-ui",
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    dependencies = "vim-dadbod",
    keys = {
      { "<leader>D", "<cmd>DBUIToggle<CR>", desc = "Toggle DBUI" },
    },
    init = function()
      local data_path = vim.fn.stdpath("data")

      vim.g.db_ui_auto_execute_table_helpers = 1
      vim.g.db_ui_save_location = data_path .. "/dadbod_ui"
      vim.g.db_ui_show_database_icon = true
      vim.g.db_ui_tmp_query_location = data_path .. "/dadbod_ui/tmp"
      vim.g.db_ui_use_nerd_fonts = true
      vim.g.db_ui_use_nvim_notify = true

      -- NOTE: The default behavior of auto-execution of queries on save is disabled
      -- this is useful when you have a big query that you don't want to run every time
      -- you save the file running those queries can crash neovim to run use the
      -- default keymap: <leader>S
      vim.g.db_ui_execute_on_save = false
    end,
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = { ensure_installed = { "sql" } },
  },

  -- Edgy integration

  -- blink.cmp integration
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        default = { "dadbod" },
        providers = {
          dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
        },
      },
    },
    dependencies = {
      "kristijanhusak/vim-dadbod-completion",
    },
  },

  -- Linters & formatters
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "sqlfluff" } },
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      for _, ft in ipairs(sql_ft) do
        opts.linters_by_ft[ft] = opts.linters_by_ft[ft] or {}
        table.insert(opts.linters_by_ft[ft], "sqlfluff")
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters.sqlfluff = {
        args = { "format", "--dialect=ansi", "-" },
      }
      for _, ft in ipairs(sql_ft) do
        opts.formatters_by_ft[ft] = opts.formatters_by_ft[ft] or {}
        table.insert(opts.formatters_by_ft[ft], "sqlfluff")
      end
    end,
  },
}