-- 背景透明的一键开关（<leader>uT）。
-- 为什么不走「改开关 + 重新 colorscheme」：catppuccin 把编译结果缓存在 stdpath("cache")，
-- 开关变了但缓存哈希不变，重新上色拿到的还是旧主题（实测如此），所以这里直接改高亮组。
local M = {}

local function flavour()
  local f = (vim.g.colors_name or ""):match("^catppuccin%-(.+)$")
  return f or "frappe"
end

local function palette()
  local ok, mod = pcall(require, "catppuccin.palettes")
  if not ok then
    return nil
  end
  local ok2, pal = pcall(mod.get_palette, flavour())
  return ok2 and pal or nil
end

--- 当前是否处于透明状态
---@return boolean
function M.enabled()
  return vim.api.nvim_get_hl(0, { name = "Normal" }).bg == nil
end

---@param group string
---@param field "bg"|"fg"
---@param value string|integer
local function set_field(group, field, value)
  local h = vim.api.nvim_get_hl(0, { name = group, link = false })
  h[field] = value
  vim.api.nvim_set_hl(0, group, h)
end

--- 打开/关闭背景透明（只动高亮组，不动配色方案）
---@param on boolean
function M.set(on)
  local p = palette()
  if not p then
    vim.notify("透明开关目前只支持 catppuccin 配色", vim.log.levels.WARN)
    return
  end
  local none = "NONE"
  -- 浮层类：透明时不能有底色，否则在透出壁纸的画布上就是一块突兀色块
  set_field("TreesitterContext", "bg", on and none or p.base)
  set_field("TreesitterContextLineNumber", "bg", on and none or p.base)
  set_field("WhichKey", "bg", on and none or p.mantle)
  -- 编辑器主体
  for _, g in ipairs({ "Normal", "NormalNC", "SignColumn" }) do
    set_field(g, "bg", on and none or p.base)
  end
  for _, g in ipairs({ "StatusLine", "StatusLineNC", "TabLineFill" }) do
    set_field(g, "bg", on and none or p.mantle)
  end
  set_field("Folded", "bg", on and none or p.surface1)
  set_field("WinSeparator", "fg", on and p.surface1 or p.crust)
  -- 面板（NormalFloat / Pmenu / Lazy* / Trouble / Snacks 等）两种状态下都应不透明，这里不动
end

return M
