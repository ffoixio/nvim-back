-- 高亮"字体样式"（斜体）的统一出口，与配色主题无关：**白名单式**。
--
-- 为什么需要这一层：颜色归主题管，但"哪些组用斜体"各主题默认完全不同（实测同一款字体）：
--   catppuccin  注释 + 条件语句，另外 @module / @namespace / @tag.attribute 等零散组也斜
--   tokyonight  注释 + 关键字
--   everforest  只有注释
--   rose-pine   styles.italic 一个总开关
--   gruvbox     注释 + 字符串 + 折叠（已从本配置删除，仅作对比）
-- 于是"换主题"看起来像"换字体"。
--
-- 规则：**只有命中 M.italic 里任一模式的组是斜体，其余一律拉平成不斜**（不管主题怎么设）。
-- 白名单式的好处是换主题结果永远一致，主题偷偷多斜了哪个组也会被自动拉平。
-- 只动 italic 这一个位，颜色一个字不碰。两条实现上的讲究（都是实测踩出来的）：
--   1. 属性加在**组自己**身上、保留 link（nvim 支持 link + 属性覆盖），不要改链接目标 ——
--      否则会连累同族：tokyonight 的 Conditional 是 link 到 Statement，改目标会把 Statement 弄斜。
--   2. 判断"该不该斜"要沿 link 链看落地组：everforest 的 TSComment link 到 Comment、
--      @markup.italic link 到 TSEmphasis，只看自己的名字会漏。
-- 想调整观感只改 M.italic，例：想让函数名/类型名也斜，加 "^@function" / "^@type"。
local M = {}

M.italic = {
  -- 注释：信息密度低，斜体让它退到背景（最通行的做法）
  "^Comment$",
  "^@comment",
  -- 条件语句：catppuccin 的默认观感，保留成基准
  "^Conditional$",
  "^@conditional",
  -- nvim 自带的 Lua 查询用 @keyword.conditional 标 if/then/else。必须单列：
  -- 关键字族整体不斜（见文件头的取舍），这里把条件语句捞回来。
  "^@keyword%.conditional",
  -- markdown / 文本里的"强调"：字面意思就是斜体
  "^@markup%.italic$",
  "^@text%.emphasis$",
}

--- 组名是否命中白名单
---@param name string
---@return boolean
local function wants(name)
  for _, pat in ipairs(M.italic) do
    if name:match(pat) then
      return true
    end
  end
  return false
end

--- 应用白名单：命中 -> 加 italic；未命中的组若自身是斜的就拉平。幂等，只动 italic 一个位。
--- 性能：每次 :colorscheme 只取一遍高亮表（约 1k 组，实测 ~0.3ms），链接用纯 Lua 解析，
--- 只有需要改动的组才调用 nvim_set_hl（幂等时约 3ms，启动实测见 .test 记录）。
---@return table 本次改动统计 { italic = 设成斜体的组数, cleared = 拉平的组数 }
function M.apply()
  local names = vim.fn.getcompletion("", "highlight")
  local hl = {}
  for _, name in ipairs(names) do
    hl[name] = vim.api.nvim_get_hl(0, { name = name })
  end

  --- 沿 link 链找到最终落地的组名（查表，不再调 API）
  ---@param name string
  ---@return string
  local function landed(name)
    local seen = {}
    while name and not seen[name] do
      seen[name] = true
      local h = hl[name]
      if h and h.link then
        name = h.link
      else
        break
      end
    end
    return name
  end

  local italic, cleared = 0, 0
  for _, name in ipairs(names) do
    local h = hl[name]
    if wants(name) or wants(landed(name)) then
      if h.italic ~= true then
        h.italic = true
        vim.api.nvim_set_hl(0, name, h --[[@as vim.api.keyset.highlight]])
        italic = italic + 1
      end
    elseif h.italic then
      h.italic = false
      vim.api.nvim_set_hl(0, name, h --[[@as vim.api.keyset.highlight]])
      cleared = cleared + 1
    end
  end
  M.last = { italic = italic, cleared = cleared }
  return M.last
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("config_styles", { clear = true }),
  callback = function()
    M.apply()
  end,
})

-- NOTE: 插件会在配色之后才建自己的组（which-key / snacks / lualine…），所以 VeryLazy
-- 再刷一遍，跟 util/transparency.lua 同一个思路。
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    M.apply()
  end,
})

return M
