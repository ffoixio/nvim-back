local U = require("util.init")


local diagnostics = "rust-analyzer"

require("config.modules").register_lang("rust", { name = "rust", lsp = { "rust-analyzer" }, ts = { "rust" } })
return {

  -- LSP for Cargo.toml
  {
    "Saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    opts = {
      completion = {
        crates = {
          enabled = true,
        },
      },
      lsp = {
        enabled = true,
        actions = true,
        completion = true,
        hover = true,
      },
    },
  },

  -- Add Rust & related to treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "rust", "ron" } },
  },

  -- Install rust-analyzer via mason (prebuilt binary, no rustup/cargo needed)
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "rust-analyzer" } },
  },

  {
    "mrcjkb/rustaceanvim",
    ft = { "rust" },
    opts = {
      server = {
        on_attach = function(_, bufnr)
          vim.keymap.set("n", "<leader>cR", function()
            vim.cmd.RustLsp("codeAction")
          end, { desc = "Code Action", buffer = bufnr })
        end,
        default_settings = {
          -- rust-analyzer language server configuration
          ["rust-analyzer"] = {
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
              buildScripts = {
                enable = true,
              },
            },
            -- Add clippy lints for Rust if using rust-analyzer
            checkOnSave = diagnostics == "rust-analyzer",
            -- Enable diagnostics if using rust-analyzer
            diagnostics = {
              enable = diagnostics == "rust-analyzer",
            },
            procMacro = {
              enable = true,
            },
            files = {
              exclude = {
                ".direnv",
                ".git",
                ".jj",
                ".github",
                ".gitlab",
                "bin",
                "node_modules",
                "target",
                "venv",
                ".venv",
              },
              -- Avoid Roots Scanned hanging, see https://github.com/rust-lang/rust-analyzer/issues/12613#issuecomment-2096386344
              watcher = "client",
            },
          },
        },
      },
    },
    config = function(_, opts)
      vim.g.rustaceanvim = vim.tbl_deep_extend("keep", vim.g.rustaceanvim or {}, opts or {})
      if vim.fn.executable("rust-analyzer") == 0 then
        U.warn(
          "**rust-analyzer** not found in PATH, please install it.\nhttps://rust-analyzer.github.io/",
          { title = "rustaceanvim", once = true }
        )
      end
    end,
  },

  -- Correctly setup lspconfig for Rust 🚀
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bacon_ls = {
          enabled = diagnostics == "bacon-ls",
        },
        rust_analyzer = { enabled = false },
      },
    },
  },

}
