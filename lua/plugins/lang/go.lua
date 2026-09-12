require("config.modules").register_lang("go", { name = "go", lsp = { "gopls" }, ts = { "go", "gomod", "gosum", "gowork" }, fmt = { "goimports" }, lint = { "golangci-lint" } })
return {
  -- 语法高亮：go / gomod / gosum / gowork 覆盖 .go、go.mod、go.sum、go.work
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "go", "gomod", "gosum", "gowork" } },
  },

  -- LSP：gopls（格式化/整理 import 也走它的 LSP 能力）
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {},
      },
    },
  },

  -- 工具：注意还需要系统装 Go 工具链（pacman -S go），gopls 要靠它做类型检查
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "gopls", "goimports", "golangci-lint" } },
  },

  -- 格式化：goimports（gofmt + import 整理）
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        go = { "goimports" },
      },
    },
  },

  -- lint：golangci-lint（mason 里早就装了，之前是孤儿）
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.go = vim.list_extend(opts.linters_by_ft.go or {}, { "golangcilint" })
    end,
  },
}
