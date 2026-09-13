-- 主题/变体用哪个在 lua/config/theme.lua 里选（切主题只改那一行），
-- 这里只描述"每个主题长什么样"：没启用的主题 enabled = false，lazy 既不加载也不安装。
local T = require("config.theme")


-- 背景透明状态统一由 lua/util/transparency.lua 管理（含运行时 <leader>uT 开关与状态记忆）。
local function transparent()
  return require("util.transparency").default()
end

-- 该主题的"变体" + 它自己的设置（变体字段名各主题不同，映射在 config/theme.lua）
local function opts(name, extra)
  return vim.tbl_deep_extend("force", T.opts(name), extra or {})
end

  -- catppuccin

local specs = {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    -- 兜底主题：theme.load() 出错时会回退到 catppuccin/frappe，所以它永远 enabled（不激活时 lazy 才不加载）
    enabled = true,
    lazy = not T.is("catppuccin"),
    priority = 1000,
    opts = opts("catppuccin", {
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
        local Tr = require("util.transparency")
        local on = transparent()
        local hl = {}
        local function put(group, field, value)
          hl[group] = hl[group] or {}
          hl[group][field] = value == "NONE" and "NONE" or colors[value]
        end
        -- 跟着透明状态走的那批：新增组只改 util/transparency.lua 里的 M.follow
        for _, item in ipairs(Tr.follow) do
          put(item[1], item[2], on and item[3] or item[4])
        end
        -- 透明模式下把"盖在代码上"、必须实底的面板钉回来（默认空，见 util/transparency.lua）
        if on then
          for _, item in ipairs(Tr.always_opaque) do
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
        -- 光标行：catppuccin 默认是 darken(surface0, 0.64, base) ≈ #3B3F52，只比底色亮一点点，
        -- 透明背景下几乎看不出来（实测真机上确实在画，只是太暗；这个值跟透明开关无关）。
        -- 提到 surface1，和 picker 里选中行（Visual）同亮度；想更淡就换 surface0。
        hl.CursorLine = { bg = colors.surface1 }
        -- 同名单词高亮（illuminate / LSP）：透明模式下底色被去掉（见 util/transparency.lua），
        -- 这里常驻一条下划线，保证还能看出哪些地方出现了同一个词。
        for _, g in ipairs({
          "IlluminatedWordText",
          "IlluminatedWordRead",
          "IlluminatedWordWrite",
          "illuminatedWord",
          "illuminatedCurWord",
        }) do
          hl[g] = hl[g] or {}
          hl[g].underline = true
        end
        -- 上下文浮层底部那条细下划线：与透明无关，一直保留
        hl.TreesitterContextBottom = { sp = colors.surface2, style = { "underline" } }
        return hl
      end,
    }),
    specs = {
      {
        "akinsho/bufferline.nvim",
        optional = true,
        opts = function(_, o)
          if (vim.g.colors_name or ""):find("catppuccin") then
            o.highlights = require("catppuccin.special.bufferline").get_theme()
          end
        end,
      },
    },
  },

}

  -- 其余主题：repo / 变体字段 / 允许取值 / 透明选项 全部登记在 config/theme.lua 的 M.themes 里，
  -- 这里只做装配（catppuccin 单写是因为它额外带 custom_highlights / integrations / specs）。
  local function theme_spec(name)
    local t = T.themes[name]
    return {
      t.repo,
      name = t.plugin,
      -- 告诉 lazy 的隐式 setup 该 require 哪个模块（主题表里的 module 字段）
      main = t.module,
      enabled = T.enabled(name),
      lazy = not T.is(name),
      priority = 1000,
      opts = vim.tbl_deep_extend("force", T.opts(name), t.transparent(transparent())),
    }
  end
  for _, name in ipairs(T.list()) do
    if name ~= "catppuccin" then
      specs[#specs + 1] = theme_spec(name)
    end
  end

  return specs
