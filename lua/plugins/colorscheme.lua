-- 背景透明状态统一由 lua/util/transparency.lua 管理（含运行时 <leader>uT 开关与状态记忆）。
local function transparent()
  return require("util.transparency").default()
end

return {

  -- tokyonight
  {
    "folke/tokyonight.nvim",
    lazy = vim.g.colorscheme ~= "tokyonight",
    priority = 1000,
    opts = { style = "storm", transparent = transparent() },
  },

  -- catppuccin
  {
    "catppuccin/nvim",
    lazy = vim.g.colorscheme ~= "catppuccin",
    priority = 1000,
    name = "catppuccin",
    opts = {
      transparent_background = transparent(),
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
        local T = require("util.transparency")
        local on = transparent()
        local hl = {}
        local function put(group, field, value)
          hl[group] = hl[group] or {}
          hl[group][field] = value == "NONE" and "NONE" or colors[value]
        end
        -- 跟着透明状态走的那批：新增组只改 util/transparency.lua 里的 M.follow
        for _, item in ipairs(T.follow) do
          put(item[1], item[2], on and item[3] or item[4])
        end
        -- 透明模式下把"盖在代码上"的面板强制回实底
        if on then
          for _, item in ipairs(T.always_opaque) do
            put(item[1], item[2], item[3])
          end
        end
        -- 注释关键词的色块 = Neovim 原生注解层：nvim-treesitter 的
        -- runtime/queries/comment/highlights.scm 会把注释里的 TODO/FIXME/NOTE… 标成
        -- @comment.todo / @comment.error / @comment.note 等捕获，跟语法高亮同一帧出现
        -- （不像插件那层要等文件事件 + 定时器）。catppuccin 原生就是"彩色底 + base 字"，
        -- 这里只把颜色换成和 todo-comments 插件一致的语义色（picker 列表里的色块条用的就是那套），
        -- 保证列表里和缓冲区里看到的颜色一致；@text.* 是同一批注解在非注释语境下的名字。
        for group, key in pairs({
          ["@comment.todo"] = "sky",
          ["@comment.note"] = "teal",
          ["@comment.hint"] = "teal",
          ["@comment.error"] = "red",
          ["@comment.warning"] = "yellow",
          ["@text.todo"] = "sky",
          ["@text.note"] = "teal",
          ["@text.danger"] = "red",
          ["@text.warning"] = "yellow",
        }) do
          hl[group] = { fg = colors.base, bg = colors[key] }
        end
        -- picker 选中行常驻的下划线：透明模式下底色被去掉（见 util/transparency.lua），
        -- 靠这条不铺底的线还能一眼看出选中了哪一行。
        hl.SnacksPickerListCursorLine = { underline = true, sp = colors.surface2 }
        -- 上下文浮层底部那条细下划线：与透明无关，一直保留
        hl.TreesitterContextBottom = { sp = colors.surface2, style = { "underline" } }
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
