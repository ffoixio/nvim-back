-- shell（bash / zsh）支持。单独成文件是因为它原先混在 plugins/util.lua 里，
-- 而那个文件还装着 snacks / persistence / direnv 等杂项；这样它也能在 config/modules.lua 里单独开关。
return {
  -- 语法高亮：bash 在 plugins/treesitter.lua 的基础清单里，这里补 zsh
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "zsh" } },
  },

  -- LSP：bash-language-server（zsh 没有成熟 LSP，只给高亮）
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
      },
    },
  },

  -- 工具：shellcheck（lint）+ bash-language-server；格式化（shfmt）在 plugins/formatting.lua 里为 sh 配置
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "shellcheck", "bash-language-server" } },
  },
}
