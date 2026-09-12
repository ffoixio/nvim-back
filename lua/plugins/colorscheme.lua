-- 背景透明总开关：只改这一处。true = 编辑器背景交给终端（终端的 opacity / acrylic 才看得见），
-- picker / lazy / 补全菜单 / 通知这些面板仍保持实底；false = 常规不透明。
-- 前置条件与注意事项见仓库根目录 TODO.md。
local transparent = true

return {

  -- tokyonight
  {
    "folke/tokyonight.nvim",
    lazy = vim.g.colorscheme ~= "tokyonight",
    priority = 1000,
    opts = { style = "storm", transparent = transparent },
  },

  -- catppuccin
  {
    "catppuccin/nvim",
    lazy = vim.g.colorscheme ~= "catppuccin",
    priority = 1000,
    name = "catppuccin",
    opts = {
      transparent_background = transparent,
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
        -- 上下文浮层：透明时不能有底色（浮窗是“替换”格子，只有 winblend > 0 才会和背后代码混色叠字），
        -- 否则在透出壁纸的画布上就是一块突兀色块；不透明时用 base，和正文完全同色。见 TODO.md。
        local float_bg = transparent and "NONE" or colors.base
        local hl = {
          TreesitterContext = { fg = colors.text, bg = float_bg },
          TreesitterContextBottom = { sp = colors.surface2, style = { "underline" } },
          TreesitterContextLineNumber = { fg = colors.overlay0, bg = float_bg },
        }
        if transparent then
          -- 透明模式下 catppuccin 会把这些“盖在代码上”的面板也清成透明，底下代码会透上来，
          -- 所以强制回实底（颜色取 catppuccin 不透明时的原值）。
          hl.NormalFloat = { bg = colors.mantle }
          hl.FloatBorder = { bg = colors.mantle }
          hl.Pmenu = { bg = colors.mantle }
          hl.NotifyBackground = { bg = colors.mantle }
          hl.LazyNormal = { bg = colors.mantle }
          hl.LazyButton = { bg = colors.surface0 }
          hl.LazyButtonActive = { bg = colors.surface1 }
          hl.TroubleNormal = { bg = colors.crust }
          hl.SnacksPickerNormal = { bg = colors.base }
        end
        return hl
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
