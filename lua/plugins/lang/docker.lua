require("config.modules").register_lang("docker", { name = "docker", lsp = { "docker-langserver" }, ts = { "dockerfile" }, lint = { "hadolint" } })
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "dockerfile" } },
  },
  {
    "mason.nvim",
    opts = { ensure_installed = { "hadolint" } },
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        dockerfile = { "hadolint" },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        dockerls = {},
        docker_compose_language_service = {},
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "dockerfile-language-server", "docker-compose-language-service" } },
  },
}
