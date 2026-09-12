return {

  -- tokyonight
  {
    "folke/tokyonight.nvim",
    lazy = vim.g.colorscheme ~= "tokyonight",
    priority = 1000,
    opts = { style = "storm", transparent = true }, -- 同上：切到 tokyonight 也保持透明
  },

  -- catppuccin
  {
    "catppuccin/nvim",
    lazy = vim.g.colorscheme ~= "catppuccin",
    priority = 1000,
    name = "catppuccin",
    opts = {
      -- 不画编辑器背景（bg = NONE），把画布交给终端 —— 这样终端的 opacity / acrylic 才看得见。
      -- 注意：winblend/pumblend 是另一层（浮窗与弹出菜单和「编辑器内容」混色），不能替代它。
      transparent_background = true,
      lsp_styles = {
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
      integrations = {
        aerial = true,
        alpha = true,
        cmp = true,
        dashboard = true,
        flash = true,
        fzf = true,
        grug_far = true,
        gitsigns = true,
        headlines = true,
        illuminate = true,
        indent_blankline = { enabled = true },
        leap = true,
        lsp_trouble = true,
        mason = true,
        mini = true,
        navic = { enabled = true, custom_bg = "lualine" },
        neotest = true,
        neotree = true,
        noice = true,
        notify = true,
        snacks = true,
        telescope = true,
        treesitter_context = true,
        which_key = true,
      },
      -- treesitter-context（顶部粘住当前函数 / if 块的签名）被 catppuccin 集成铺成整块
      -- mantle 深色底，看着就是一块色块。这里改成与正文同底色，只在最后一行留一条细
      -- 下划线当分隔；底色用 base，和正文完全同色，浮动窗口也不会变透明。
      -- custom_highlights 在 catppuccin 里优先级最高（compiler.lua 用 "keep" 合并），
      -- 所以能盖掉集成。
      custom_highlights = function(colors)
        return {
          TreesitterContext = { fg = colors.text, bg = colors.base },
          TreesitterContextBottom = { sp = colors.surface2, style = { "underline" } },
          TreesitterContextLineNumber = { fg = colors.overlay0, bg = colors.base },
        }
      end,
    },
    specs = {
      {
        "akinsho/bufferline.nvim",
        optional = true,
        opts = function(_, opts)
          if (vim.g.colors_name or ""):find("catppuccin") then
            opts.highlights = require("catppuccin.special.bufferline").get_theme()
          end
        end,
      },
    },
  },
}
