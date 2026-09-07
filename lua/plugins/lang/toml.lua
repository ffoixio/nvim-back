return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      taplo = {},
    },
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "taplo" } },
  },
}