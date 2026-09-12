-- 主题开关：切主题 / 换变体只改这一个文件（和 config/modules.lua 一个思路）。
--
--   active    —— 当前用哪个主题（决定加载哪个主题插件、:colorscheme 用哪个名字）
--   available —— 哪些主题"装上并可选"；不在这里的主题，lazy 既不会安装也不会加载
--   variant   —— 每个主题用哪个变体。下面把每个主题的**全部取值**都列了出来，
--                除了当前在用的那行，其余都注释着。
--
-- 换变体两种写法等价，随便挑：
--   ① 直接改当前生效那行的字符串（只改一处，推荐）；
--   ② 把目标那行取消注释、把当前那行注释掉。
--
-- 每个主题"变体"字段名不同，映射见 var_field；nightfox 例外 —— 它的变体本身就是 colorscheme 名，
-- 由 scheme() 处理。
--
-- 换到非 catppuccin 主题时还要确认两件事（详见 TRANSPARENCY.md 的"换主题"）：
--   ① 该主题的透明选项名 —— plugins/colorscheme.lua 里每个主题块的 extra 都写了，首次用要确认是否生效；
--   ② util/transparency.lua 的 palette() 目前只认 catppuccin，关掉透明时面板底色会用错颜色。

local M = {}

M.active = "catppuccin"

M.available = {
  "catppuccin",
  -- 想用哪个就取消注释（tokyonight 之前已经装过，其余几个会在下次启动时自动装）
  -- "tokyonight",
  -- "rose-pine",
  -- "nightfox",
  -- "gruvbox",
  -- "everforest",
}

--- 各主题"变体"在 opts 里的字段名（nightfox 没有：它的变体是独立的 colorscheme 名）
M.var_field = {
  catppuccin = "flavour",
  tokyonight = "style",
  ["rose-pine"] = "variant",
  gruvbox = "contrast",
  everforest = "background",
}

M.variant = {
  -- ── catppuccin（当前使用）────────────────────────────
  catppuccin = "frappe",
  -- catppuccin = "latte"        -- 浅色
  -- catppuccin = "macchiato"
  -- catppuccin = "mocha"

  -- ── tokyonight（需先在 available 里取消注释）──────────
  -- tokyonight = "storm"
  -- tokyonight = "night"
  -- tokyonight = "moon"
  -- tokyonight = "day"          -- 浅色

  -- ── rose-pine ────────────────────────────────────────
  -- ["rose-pine"] = "main"
  -- ["rose-pine"] = "moon"
  -- ["rose-pine"] = "dawn"      -- 浅色

  -- ── gruvbox（深浅由 vim.o.background 决定）────────────
  -- gruvbox = "hard"
  -- gruvbox = "soft"
  -- gruvbox = ""                -- 默认对比度

  -- ── everforest（深浅由 vim.o.background 决定）─────────
  -- everforest = "hard"
  -- everforest = "medium"
  -- everforest = "soft"

  -- ── nightfox（变体是独立主题名，由 scheme() 取用）─────
  -- nightfox = "duskfox"        -- 深色（偏紫）
  -- nightfox = "nightfox"       -- 深色（默认）
  -- nightfox = "nordfox"
  -- nightfox = "terafox"
  -- nightfox = "carbonfox"
  -- nightfox = "dayfox"         -- 浅色
  -- nightfox = "dawnfox"        -- 浅色
}

--- 当前生效的是不是这个主题
---@param name string
---@return boolean
function M.is(name)
  return M.active == name
end

--- 这个主题要不要装上并可选（当前主题一定可用）
---@param name string
---@return boolean
function M.enabled(name)
  return M.is(name) or vim.tbl_contains(M.available, name)
end

--- 该主题用来切变体的 opts 片段（该主题没有变体字段时返回空表）
---@param name string
---@return table
function M.opts(name)
  local field = M.var_field[name]
  return field and { [field] = M.variant[name] } or {}
end

--- 主题名 → :colorscheme 用的名字（nightfox 的变体本身就是主题名）
---@param name string
---@return string
function M.scheme(name)
  if name == "nightfox" then
    return M.variant[name] or "nightfox"
  end
  return name
end

return M
