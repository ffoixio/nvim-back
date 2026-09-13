-- 背景透明相关的高亮组总表 + 运行时开关（<leader>uT）。
--
-- 为什么要总表：透明/不透明两种状态要动的高亮组不止一个，而用到它们的地方有两处
-- （配色编译时的 custom_highlights、运行时的开关）。两边都从这里读，新增组只改这一处。
--
-- NOTE: 表里的值写 catppuccin 调色板键名（base / mantle / surface0 …）或 "NONE"，供**编译期**
-- （catppuccin 的 custom_highlights）使用；运行时的开关/换主题走下面的快照机制，因而与主题无关。
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
  -- NOTE: 浮窗 / 弹出菜单那一族的两个"根"。所有浮窗的底色最终都来自它们：
  --   NormalFloat —— 浮窗本体（which-key、lazy、notify、Trouble、snacks 各种 picker、hover 文档…）
  --   Pmenu       —— 补全 / 命令行弹出菜单
  -- 把它们接进开关 = 一次性覆盖所有浮窗：以后装新插件，只要它用标准浮窗就自动跟着透，
  -- 不用再"遇到一个加一个"（之前 picker 就是这样一个个补的）。确实需要实底的特例写回 M.always_opaque。
  { "NormalFloat", "bg", "NONE", "mantle" },
  { "NormalFloat", "fg", "text", "text" },
  { "Pmenu", "bg", "NONE", "mantle" },
  { "NotifyBackground", "bg", "NONE", "mantle" },
  { "LazyNormal", "bg", "NONE", "mantle" },
  { "LazyButton", "bg", "NONE", "surface0" },
  { "LazyButtonActive", "bg", "NONE", "surface1" },
  { "TroubleNormal", "bg", "NONE", "crust" },
  -- NOTE: 浮窗投影。catppuccin 默认是一条带 blend 的深色带（FloatShadow / FloatShadowThrough），
  -- 透明模式下别处都透了、它却留一条黑边，是最没道理的一块实底；跟着开关走。
  { "FloatShadow", "bg", "NONE", "crust" },
  { "FloatShadowThrough", "bg", "NONE", "crust" },
  -- NOTE: illuminate / LSP 的"同名单词"高亮，默认是给整个词铺底（一小块实色）。
  -- 透明模式下取消底色、改用下划线（下划线在 plugins/colorscheme.lua 里常驻加上）。
  { "IlluminatedWordText", "bg", "NONE", "surface1" },
  { "IlluminatedWordRead", "bg", "NONE", "surface1" },
  { "IlluminatedWordWrite", "bg", "NONE", "surface2" },
  { "illuminatedWord", "bg", "NONE", "surface1" },
  { "illuminatedCurWord", "bg", "NONE", "surface1" },
  { "LspReferenceText", "bg", "NONE", "surface1" },
  { "LspReferenceRead", "bg", "NONE", "surface1" },
  { "LspReferenceWrite", "bg", "NONE", "surface2" },
}

-- 透明模式下仍强制实底的例外：{组名, 字段, 值}
-- NOTE: 默认空。以前这里放的是"盖在代码上"的面板（NormalFloat / Pmenu / Trouble…），
-- 结果变成"遇到一个浮窗补一个"；现在它们都在 M.follow 里跟着开关走。
-- 如果以后觉得哪个浮窗透过去看不清（两层字叠一起），把它加回这里一行即可。
M.always_opaque = {}

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
  -- ① 先看 :colorscheme 的名字（catppuccin-frappe）——用主题名指定变体时，这才是当前真正生效的那个
  local from_name = (vim.g.colors_name or ""):match("^catppuccin%-(.+)$")
  if from_name then
    return from_name
  end
  -- ② 名字里没有变体（说明是在 opts 里写 flavour = "..."），就问主题自己
  local ok, cat = pcall(require, "catppuccin")
  if ok and type(cat.flavour) == "string" then
    return cat.flavour
  end
  -- ③ 兜底
  return "frappe"
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
  -- nvim_get_hl 返回 keyset.get_hl_info，字段结构和 nvim_set_hl 要的 keyset.highlight 一致，
  -- 但 LuaLS 不认（param-type-mismatch），显式 cast 掉这个误报。
  vim.api.nvim_set_hl(0, group, h --[[@as vim.api.keyset.highlight]])
end

-- 运行时（开关 / VeryLazy / 换主题）用快照，而不是 catppuccin 的调色板：
-- 旧实现只会 require("catppuccin.palettes")，换到别的主题时会拿 catppuccin 的颜色去刷别人的界面
-- （实测 everforest 下 NormalFloat.fg 被刷成 catppuccin 的 #c6d0f5、浮窗还留着两块底色）。
-- 现在：不透明值 = 主题自己给的值（快照），透明值 = bg 置 NONE、fg 显式写回主题的值
-- （显式写是为了不被 default = true 的 link 盖回去）。
local snapshot = {}

--- 抓一次快照：在"配色刚生效、还没被我们改过"时调用（ColorScheme 回调里就是这么用的）
function M.snapshot()
  snapshot = {}
  for _, item in ipairs(M.follow) do
    local group, field = item[1], item[2]
    snapshot[group] = snapshot[group] or {}
    local v = vim.api.nvim_get_hl(0, { name = group, link = false })[field]
    if v ~= nil then
      snapshot[group][field] = v
    end
  end
end

--- 应用某个状态（不写状态文件）
---@param on boolean
function M.apply(on)
  for _, item in ipairs(M.follow) do
    local group, field = item[1], item[2]
    snapshot[group] = snapshot[group] or {}
    local cur = vim.api.nvim_get_hl(0, { name = group, link = false })[field]
    if on then
      if cur ~= nil and snapshot[group][field] == nil then
        snapshot[group][field] = cur
      end
      set_field(group, field, field == "bg" and "NONE" or (cur or snapshot[group][field] or "NONE"))
    elseif snapshot[group][field] ~= nil then
      set_field(group, field, snapshot[group][field])
    end
  end
  if on then
    local p = palette()
    for _, item in ipairs(M.always_opaque) do
      set_field(item[1], item[2], (p and p[item[3]]) or item[3])
    end
  end
end

--- 打开/关闭背景透明，并把状态写进状态文件（下次启动沿用）
--- NOTE: 透明同时也是**各主题自己的选项**（config/theme.lua 里的 M.themes.<主题>.transparent(on)），
--- 所以状态文件写完要通知主题重配一遍：否则"关掉透明"时那些组没有实底颜色可恢复（实测 Normal.bg
--- 仍是 nil）。用事件解耦，免得这里直接依赖 config.theme。
---@param on boolean
function M.set(on)
  if not pcall(vim.fn.writefile, { tostring(on) }, STATE) then
    vim.notify(("写不进 %s：透明状态本次已生效，但下次启动不会记住"):format(STATE), vim.log.levels.WARN)
  end
  M.apply(on)
  vim.api.nvim_exec_autocmds("User", { pattern = "TransparencyChanged", modeline = false })
end

-- 换主题时：先抓新主题的快照，再按当前透明状态重刷一遍 —— 这是"切主题也全部生效"的关键。
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("config_transparency", { clear = true }),
  callback = function()
    M.snapshot()
    M.apply(M.enabled())
  end,
})

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
