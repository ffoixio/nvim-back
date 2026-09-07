return {
  -- 语法高亮
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "verilog", "systemverilog" } },
  },

  -- LSP：verible（verible-verilog-ls，含诊断/补全/跳转）
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        verible = {},
      },
    },
  },

  -- 安装 verible（LSP + 格式化 + lint 一体）
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "verible" } },
  },

  -- 格式化：verible-verilog-format
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        verilog = { "verible" },
        systemverilog = { "verible" },
      },
    },
  },

  -- lint：verilator（系统包，装了才启用；verible LSP 本身已带诊断）
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      if vim.fn.executable("verilator") == 1 then
        opts.linters_by_ft = opts.linters_by_ft or {}
        opts.linters_by_ft.verilog = vim.list_extend(opts.linters_by_ft.verilog or {}, { "verilator" })
        opts.linters_by_ft.systemverilog = vim.list_extend(opts.linters_by_ft.systemverilog or {}, { "verilator" })
      end
    end,
  },
}
