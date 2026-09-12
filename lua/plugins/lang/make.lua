-- 构建 / 任务运行：Makefile 与 Justfile
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "make", "just" } },
  },

  -- lint：checkmake（只对 make 有定义；just 没有现成 linter）
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.make = vim.list_extend(opts.linters_by_ft.make or {}, { "checkmake" })
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "checkmake" } },
  },

  -- 格式化：just 自带 --fmt（就地改写，所以 stdin = false）
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        just = { "just" },
      },
      formatters = {
        just = {
          command = "just",
          args = { "--justfile", "$FILENAME", "--fmt" },
          stdin = false,
        },
      },
    },
  },
}
