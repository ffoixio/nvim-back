require("config.modules").register_lang("scala", { name = "scala", ts = { "scala" } })
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "scala" } },
  },
  {
    "scalameta/nvim-metals",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      {
        -- LazyVim 原版用 telescope 扩展；这里不依赖 telescope，用 vim.ui.select
        -- （会走 snacks 的 select UI）。metals 把每个命令挂在 require("metals")[id] 上。
        "<leader>me",
        function()
          local commands = require("metals.commands").commands_table
          vim.ui.select(commands, {
            prompt = "Metals command",
            format_item = function(c)
              return c.label
            end,
          }, function(choice)
            if not choice then
              return
            end
            local fn = require("metals")[choice.id]
            if type(fn) == "function" then
              fn()
            end
          end)
        end,
        desc = "Metals commands",
      },
      {
        "<leader>mc",
        function()
          require("metals").compile_cascade()
        end,
        desc = "Metals compile cascade",
      },
      {
        "<leader>mh",
        function()
          require("metals").hover_worksheet()
        end,
        desc = "Metals hover worksheet",
      },
    },
    ft = { "scala", "sbt", "java" },
    opts = function()
      local metals_config = require("metals").bare_config()

      metals_config.init_options.statusBarProvider = "off"

      metals_config.settings = {
        verboseCompilation = true,
        showImplicitArguments = true,
        showImplicitConversionsAndClasses = true,
        showInferredType = true,
        superMethodLensesEnabled = true,
        excludedPackages = {
          "akka.actor.typed.javadsl",
          "org.apache.pekko.actor.typed.javadsl",
          "com.github.swagger.akka.javadsl",
        },
        testUserInterface = "Test Explorer",
      }


      return metals_config
    end,
    config = function(self, metals_config)
      local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = self.ft,
        callback = function()
          require("metals").initialize_or_attach(metals_config)
        end,
        group = nvim_metals_group,
      })
    end,
  },
}
