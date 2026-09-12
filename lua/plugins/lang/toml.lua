require("config.modules").register_lang("toml", { name = "toml", lsp = { "taplo" }, ts = { "toml" }, fmt = { "taplo" } })
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
