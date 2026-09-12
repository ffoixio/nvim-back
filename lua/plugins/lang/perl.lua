-- Perl（老流程/回归脚本）。perlnavigator 自带语法检查与诊断，所以不再单独挂 linter。
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "perl" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        perlnavigator = {},
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "perlnavigator" } },
  },
}
