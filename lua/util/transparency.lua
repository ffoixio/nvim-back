-- 背景透明相关的高亮组总表 + 运行时开关（<leader>uT）。
--
-- 为什么要总表：透明/不透明两种状态要动的高亮组不止一个，而用到它们的地方有两处
-- （配色编译时的 custom_highlights、运行时的开关）。两边都从这里读，新增组只改这一处。
--
-- NOTE: 值写 catppuccin 调色板键名（base / mantle / surface0 …），或 "NONE" 表示不画背景。
local M = {}

-- 跟着透明状态走：{组名, 字段, 透明时的值, 不透明时的值}
M.follow = {
  { "Normal", "bg", "NONE", "base" },
  { "NormalNC", "bg", "NONE", "base" },
  { "SignColumn", "bg", "NONE", "base" },
  { "StatusLine", "bg", "NONE", "mantle" },
  { "StatusLineNC", "bg", "NONE", "mantle" },
  { "TabLineFill", "bg", "NONE", "mantle" },
  { "Folded", "bg", "NONE", "surface1" },
  { "WinSeparator", "fg", "surface1", "crust" },
  -- NOTE: 顶部粘住的上下文浮层。它是浮动窗口，透明时若还画底色，就是画布上一块突兀色块。
  { "TreesitterContext", "bg", "NONE", "base" },
  { "TreesitterContextLineNumber", "bg", "NONE", "base" },
  -- NOTE: which-key 浮层。它窗口的 Normal 被 winhighlight 指向 WhichKeyNormal（默认 link NormalFloat），
  -- 所以单独改 WhichKey 没用，两个都要处理。
  -- 注意 fg 必须一起写死：插件是用 nvim_set_hl(..., { link = "NormalFloat", default = true }) 建这些组的，
  -- 而 default = true 会把"只设了 bg=NONE"的组当成未定义直接盖掉（实测），浮层就又变回实底；
  -- 只要组里带上 fg，default = true 就再也盖不动了。
  { "WhichKeyNormal", "bg", "NONE", "mantle" },
  { "WhichKeyNormal", "fg", "text", "text" },
  { "WhichKey", "bg", "NONE", "mantle" },
  { "WhichKey", "fg", "text", "text" },
  -- NOTE: 浮层边框 + 标题/页脚。scratch 风格会把整个 winhighlight 换成 "NormalFloat:Normal"，
  -- 于是 FloatTitle / FloatFooter 不再被映射到 Snacks*，直接用了全局组（主题里带 mantle 底），
  -- 就是标题和页脚那两小块色块。边框底色留空则会跟随所属浮窗自身的背景。
  { "FloatBorder", "bg", "NONE", "mantle" },
  { "FloatTitle", "bg", "NONE", "mantle" },
  { "FloatFooter", "bg", "NONE", "mantle" },
  { "FloatFooter", "fg", "subtext0", "subtext0" },   -- 同上：带上 fg 才不会被 default = true 盖掉
  -- NOTE: snacks 浮窗在"非当前窗口"时用的组（默认 link NormalFloat）。不放开的话，
  -- 失焦的 scratch / terminal 会突然变回实底。
  { "SnacksNormalNC", "bg", "NONE", "mantle" },
  { "SnacksNormalNC", "fg", "text", "text" },         -- 同上（它默认 link NormalFloat）
}

-- 始终不透明的面板：{组名, 字段, 值}
-- NOTE: 这些是"盖在代码上"的面板。透明模式下 catppuccin 会把它们也清成透明，
-- 底下的代码会透上来（两层字叠一起），所以只在透明模式下强制回实底。
M.always_opaque = {
  { "NormalFloat", "bg", "mantle" },
  { "Pmenu", "bg", "mantle" },
  { "NotifyBackground", "bg", "mantle" },
  { "LazyNormal", "bg", "mantle" },
  { "LazyButton", "bg", "surface0" },
  { "LazyButtonActive", "bg", "surface1" },
  { "TroubleNormal", "bg", "crust" },
  { "SnacksPickerNormal", "bg", "base" },
}

local STATE = vim.fn.stdpath("state") .. "/transparent_background"

--- 启动时的默认状态：状态文件 > 内置默认（透明）
---@return boolean
function M.default()
  local f = io.open(STATE, "r")
  if f then
    local v = f:read("*l")
    f:close()
    if v == "false" then
      return false
    elseif v == "true" then
      return true
    end
  end
  return true
end

--- 当前实际状态（以高亮组为准）
---@return boolean
function M.enabled()
  return vim.api.nvim_get_hl(0, { name = "Normal" }).bg == nil
end

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

--- 当前配色的调色板（非 catppuccin 配色时为 nil）
---@return table<string, string>|nil
M.palette = palette

---@param group string
---@param field "bg"|"fg"
---@param value string|integer
local function set_field(group, field, value)
  local h = vim.api.nvim_get_hl(0, { name = group, link = false })
  h[field] = value
  vim.api.nvim_set_hl(0, group, h)
end

--- 应用某个状态（不写状态文件）
---@param on boolean
function M.apply(on)
  local p = palette()
  if not p then
    vim.notify("透明开关目前只支持 catppuccin 配色", vim.log.levels.WARN)
    return
  end
  for _, item in ipairs(M.follow) do
    local v = on and item[3] or item[4]
    set_field(item[1], item[2], v == "NONE" and "NONE" or p[v])
  end
  if on then
    for _, item in ipairs(M.always_opaque) do
      set_field(item[1], item[2], p[item[3]])
    end
  end
end

--- 打开/关闭背景透明，并把状态写进状态文件（下次启动沿用）
---@param on boolean
function M.set(on)
  M.apply(on)
  vim.fn.writefile({ tostring(on) }, STATE)
end

-- NOTE: which-key 这类插件会在配色之后用 nvim_set_hl(..., { link = ..., default = true }) 建自己的组；
-- 而 default = true 会把"只设了 bg = NONE"的组当成未定义直接盖掉（实测如此），浮层就又变回实底。
-- 所以趁 VeryLazy（插件都加载完）再应用一次：这次会带上解析后的 fg，之后 default = true 就盖不动了。
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    M.apply(M.enabled())
  end,
})

return M
