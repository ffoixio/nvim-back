-- 高亮"字体样式"（斜体 / 粗体 / 下划线…）的统一出口，与配色主题无关。
--
-- 为什么需要这一层：颜色归主题管，但"哪些组用斜体"各主题默认完全不同（实测同一款字体）：
--   catppuccin  只有注释斜体
--   tokyonight  注释 + 关键字都斜
--   everforest  注释斜体，关键字不斜（italics = false）
--   rose-pine   styles.italic 一个总开关
--   gruvbox     注释 + 字符串 + 折叠都斜（已从本配置删除，仅作对比）
-- 于是"换主题"看起来像"换字体"。这里在 :colorscheme 之后统一刷一遍：只动 M.rules 里
-- 写明的样式位，颜色一个字不碰，也不碰链接（link 的组跳过，由被链接的组负责）。
--
-- 规则格式：{ 组名 Lua 模式, 属性表 }。同一个组被多条命中时，后面的覆盖前面的。
-- 想改观感只改这张表；markdown 的 @markup.italic / @text.emphasis 不在表里，保持原样。
local M = {}

M.rules = {
  -- 注释 + 条件语句：斜体。catppuccin 的默认就是这两个（styles.comments / styles.conditionals），
  -- 这里保留成"基准观感"，其它主题向它看齐。
  { "^Comment$", { italic = true } },
  { "^@comment", { italic = true } },
  { "^Conditional$", { italic = true } },
  { "^@conditional", { italic = true } },

  -- 关键字 / 语句 / 类型 / 字符串 / 折叠：一律不斜
  -- （tokyonight 默认斜关键字，gruvbox 默认斜字符串和折叠，这里拉平）
  { "^Keyword$", { italic = false } },
  { "^Statement$", { italic = false } },
  { "^Repeat$", { italic = false } },
  { "^Exception$", { italic = false } },
  { "^Include$", { italic = false } },
  { "^Define$", { italic = false } },
  { "^Macro$", { italic = false } },
  { "^PreCondit$", { italic = false } },
  { "^StorageClass$", { italic = false } },
  { "^Structure$", { italic = false } },
  { "^Typedef$", { italic = false } },
  { "^Type$", { italic = false } },
  { "^String$", { italic = false } },
  { "^Folded$", { italic = false } },
  { "^@keyword", { italic = false } },
  -- 例外必须写在上面那条之后（后写的覆盖先写的）：nvim 自带的 Lua 查询用 @keyword.conditional
  -- 标 if/then/else，而 catppuccin 的默认观感是"条件语句斜体"，所以这里再拉回来。
  { "^@keyword%.conditional", { italic = true } },
  { "^@repeat", { italic = false } },
  { "^@exception", { italic = false } },
  { "^@include", { italic = false } },
  { "^@storageclass", { italic = false } },
  { "^@type", { italic = false } },
  { "^@string", { italic = false } },
  { "^@number", { italic = false } },
  { "^@boolean", { italic = false } },
}

--- 应用规则。幂等；只写规则里出现的样式位，其余（颜色 / 其它属性）原样保留。
---@return integer 命中的组数（:lua print(require("util.styles").last) 可查）
function M.apply()
  local names = vim.fn.getcompletion("", "highlight")
  local hit = 0
  for _, name in ipairs(names) do
    local attrs
    for _, rule in ipairs(M.rules) do
      if name:match(rule[1]) then
        attrs = vim.tbl_extend("force", attrs or {}, rule[2])
      end
    end
    if attrs then
      local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
      if not hl.link then
        for k, v in pairs(attrs) do
          hl[k] = v
        end
        vim.api.nvim_set_hl(0, name, hl --[[@as vim.api.keyset.highlight]])
        hit = hit + 1
      end
    end
  end
  M.last = hit
  return hit
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
