
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
      -- completion.addCompletionSource(...)。我们用的是 blink（见本文件底部 providers.dadbod），这条老
      -- 分支无用，但它一报错就会打断本次加载：
      --   Failed to source .../after/plugin/vim_dadbod_completion.lua:8:
      --   attempt to call field 'addCompletionSource' (a nil value)
      -- 触发链：InsertEnter → lazy 加载 blink.cmp → 带出依赖 vim-dadbod-completion → source after/plugin。
      --
      -- 坑（上一版兜底失效的原因）：这个 init 里用来探测的 pcall(require, "completion") 会把查到的
      -- （残缺）模块写进 package.loaded，而 require 先查 loaded 再查 preload → 之后设的 preload
      -- 永远不会被用到。所以两条路都要堵：
      local ok, mod = pcall(require, "completion")
      if ok and type(mod) == "table" then
        if type(mod.addCompletionSource) ~= "function" then
          mod.addCompletionSource = function() end -- 已加载的残缺模块，就地补齐
          local src = package.searchpath("completion", package.path)
          if src then
            vim.notify("补齐了残缺的 completion 模块：" .. src, vim.log.levels.INFO)
          end
        end
      elseif not ok then
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

      -- 侧栏窗口给一个固定底色。透明模式下它的 Normal 没有底色，那一块就直接透出终端底色
      -- （截图里是纯黑），开/关侧栏时整屏重绘会明显"闪一下"；catppuccin 的 NormalSB 就是给
      -- 侧栏准备的组（crust 底），用它把侧栏变回一块正常的侧栏面板。不想要就删掉这段 autocmd。
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "dbui",
        callback = function()
          -- 换配色若没有 NormalSB（比如 tokyonight）就保持透明，别把侧栏搞成没字色的空组
          if vim.fn.hlexists("NormalSB") == 1 then
            vim.wo.winhighlight = "Normal:NormalSB,NormalNC:NormalSB"
          end
        end,
      })

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