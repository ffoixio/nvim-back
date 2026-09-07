return {

  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "julia" } },
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        julials = {
          settings = {
            -- use the same default settings as the Julia VS Code extension
            julia = {
              completionmode = "qualify",
              lint = { missingrefs = "none" },
            },
          },
        },
      },
    },
  },

  -- cmp integration

  -- blink.cmp integration
  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = { "kdheepak/cmp-latex-symbols", "saghen/blink.compat" },
    opts = {
      sources = {
        compat = { "latex_symbols" },
        providers = {
          latex_symbols = {
            kind = "LatexSymbols",
            async = true,
            opts = {
              strategy = 0, -- mixed
            },
          },
        },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "julia-lsp" } },
  },
}